import Foundation
import Combine
import Darwin
import ServiceManagement

private struct CpuTicks {
    let user: UInt64
    let nice: UInt64
    let system: UInt64
    let idle: UInt64

    init(buffer: UnsafeBufferPointer<integer_t>, baseIndex: Int) {
        user = UInt64(UInt32(bitPattern: buffer[baseIndex + Int(CPU_STATE_USER)]))
        nice = UInt64(UInt32(bitPattern: buffer[baseIndex + Int(CPU_STATE_NICE)]))
        system = UInt64(UInt32(bitPattern: buffer[baseIndex + Int(CPU_STATE_SYSTEM)]))
        idle = UInt64(UInt32(bitPattern: buffer[baseIndex + Int(CPU_STATE_IDLE)]))
    }
}

@MainActor
final class NetSpeedViewModel: ObservableObject {
    @Published private(set) var uploadSpeed: Float = 0
    @Published private(set) var downloadSpeed: Float = 0
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published private(set) var memoryUsagePercent: Float?
    @Published private(set) var cpuUsagePercent: Float?
    @Published private(set) var showResourceUsageEnabled: Bool = false

    private let refreshInterval: TimeInterval
    private let calculator: NetSpeedCalculator
    private var timerCancellable: AnyCancellable?
    private var previousCpuTicksByCore: [CpuTicks] = []

    private static let showResourceUsagePreferenceKey = "menu.show_resource_usage.enabled"
    private static let legacyShowMemoryUsagePreferenceKey = "menu.show_memory_usage.enabled"
    private static let physicalMemoryBytes = Double(ProcessInfo.processInfo.physicalMemory)
    private static let vmPageSizeBytes = Double(vm_kernel_page_size)

    init(refreshInterval: TimeInterval = 1.0) {
        self.refreshInterval = refreshInterval

        calculator = NetSpeedCalculator()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.showResourceUsagePreferenceKey) != nil {
            showResourceUsageEnabled = defaults.bool(forKey: Self.showResourceUsagePreferenceKey)
        } else {
            let legacyEnabled = defaults.bool(forKey: Self.legacyShowMemoryUsagePreferenceKey)
            if defaults.object(forKey: Self.legacyShowMemoryUsagePreferenceKey) != nil {
                defaults.set(legacyEnabled, forKey: Self.showResourceUsagePreferenceKey)
            }
            showResourceUsageEnabled = legacyEnabled
        }

        syncLaunchAtLoginStatus()
        startAutoRefresh()
        refresh()
    }

    deinit {
        timerCancellable?.cancel()
    }

    func refresh() {
        if showResourceUsageEnabled {
            memoryUsagePercent = readSystemMemoryUsagePercent()
            cpuUsagePercent = readSystemCpuUsagePercent()
        } else {
            if memoryUsagePercent != nil {
                memoryUsagePercent = nil
            }
            if cpuUsagePercent != nil {
                cpuUsagePercent = nil
            }
        }

        guard let totals = readSystemTotals() else {
            uploadSpeed = 0
            downloadSpeed = 0
            return
        }

        let timestampMs = Int64(Date().timeIntervalSince1970 * 1_000)

        let speed = calculator.pushTotals(
            NetTotalsSample(
                timestampMs: timestampMs,
                rxBytes: totals.rxBytes,
                txBytes: totals.txBytes
            )
        )

        uploadSpeed = Float(speed.uploadBps) / 1024.0
        downloadSpeed = Float(speed.downloadBps) / 1024.0
    }

    private func startAutoRefresh() {
        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    private func readSystemTotals() -> (rxBytes: UInt64, txBytes: UInt64)? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return nil
        }

        defer { freeifaddrs(pointer) }

        var rxTotal: UInt64 = 0
        var txTotal: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let current = cursor {
            let interface = current.pointee
            defer { cursor = interface.ifa_next }

            guard (interface.ifa_flags & UInt32(IFF_UP)) != 0 else { continue }
            guard (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            guard let addressPointer = interface.ifa_addr,
                  Int32(addressPointer.pointee.sa_family) == AF_LINK,
                  let namePointer = interface.ifa_name
            else {
                continue
            }

            let name = String(cString: namePointer)
            guard InterfaceFilterRule.excludeLoopbackAndVirtual.allows(name) else { continue }

            guard let dataPointer = interface.ifa_data else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee

            let (nextRxTotal, rxOverflow) = rxTotal.addingReportingOverflow(UInt64(data.ifi_ibytes))
            let (nextTxTotal, txOverflow) = txTotal.addingReportingOverflow(UInt64(data.ifi_obytes))
            rxTotal = rxOverflow ? UInt64.max : nextRxTotal
            txTotal = txOverflow ? UInt64.max : nextTxTotal
        }

        return (rxTotal, txTotal)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            syncLaunchAtLoginStatus()
        } catch {
            syncLaunchAtLoginStatus()
        }
    }

    func syncLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setShowResourceUsageEnabled(_ enabled: Bool) {
        showResourceUsageEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.showResourceUsagePreferenceKey)

        previousCpuTicksByCore.removeAll(keepingCapacity: true)

        refresh()
    }

    private func readSystemMemoryUsagePercent() -> Float? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let totalBytes = Self.physicalMemoryBytes
        guard totalBytes > 0 else {
            return nil
        }

        let pageSize = Self.vmPageSizeBytes
        let usedPages = Double(stats.active_count)
            + Double(stats.wire_count)
            + Double(stats.compressor_page_count)
        let usedBytes = usedPages * pageSize

        return Float((usedBytes / totalBytes) * 100)
    }

    private func readSystemCpuUsagePercent() -> Float? {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let ticks = UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount))
        let cores = Int(cpuCount)
        let stride = Int(CPU_STATE_MAX)
        guard ticks.count >= cores * stride else {
            return nil
        }

        if previousCpuTicksByCore.count != cores {
            previousCpuTicksByCore.removeAll(keepingCapacity: true)
            previousCpuTicksByCore.reserveCapacity(cores)
            for core in 0..<cores {
                previousCpuTicksByCore.append(
                    CpuTicks(buffer: ticks, baseIndex: core * stride)
                )
            }
            return nil
        }

        var usedDelta: UInt64 = 0
        var totalDelta: UInt64 = 0
        var countersReset = false

        for core in 0..<cores {
            let current = CpuTicks(buffer: ticks, baseIndex: core * stride)
            let previous = previousCpuTicksByCore[core]

            guard current.user >= previous.user,
                  current.nice >= previous.nice,
                  current.system >= previous.system,
                  current.idle >= previous.idle
            else {
                countersReset = true
                continue
            }

            let user = current.user - previous.user
            let nice = current.nice - previous.nice
            let system = current.system - previous.system
            let idle = current.idle - previous.idle

            usedDelta += user + nice + system
            totalDelta += user + nice + system + idle
        }

        for core in 0..<cores {
            previousCpuTicksByCore[core] = CpuTicks(
                buffer: ticks,
                baseIndex: core * stride
            )
        }

        guard !countersReset, totalDelta > 0 else {
            return nil
        }

        return Float(Double(usedDelta) * 100.0 / Double(totalDelta))
    }

}
