import Foundation
import Combine
import Darwin
import ServiceManagement
import TinyNetFFI

@MainActor
final class NetSpeedViewModel: ObservableObject {
    @Published private(set) var uploadSpeed: Float = 0
    @Published private(set) var downloadSpeed: Float = 0
    @Published private(set) var errorText: String?
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published private(set) var launchAtLoginErrorText: String?

    private let refreshInterval: TimeInterval
    private let calculator: OpaquePointer
    private var timerCancellable: AnyCancellable?

    init(refreshInterval: TimeInterval = 1.0) {
        self.refreshInterval = refreshInterval

        guard let calculator = tinynet_calculator_new() else {
            fatalError("Failed to initialize TinyNet calculator")
        }

        self.calculator = calculator
        syncLaunchAtLoginStatus()
        startAutoRefresh()
        refresh()
    }

    deinit {
        timerCancellable?.cancel()
        tinynet_calculator_free(calculator)
    }

    func refresh() {
        guard let totals = readSystemTotals() else {
            uploadSpeed = 0
            downloadSpeed = 0
            errorText = "无法读取网络接口数据"
            return
        }

        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        var speed = TinyNetSpeedFfi(upload_bps: 0, download_bps: 0)

        let result = tinynet_calculator_push_totals(
            calculator,
            timestampMs,
            totals.rxBytes,
            totals.txBytes,
            &speed
        )

        guard result == TINYNET_FFI_OK else {
            uploadSpeed = 0
            downloadSpeed = 0
            errorText = "Rust 计算失败（错误码: \(result.rawValue)）"
            return
        }

        uploadSpeed = Float(speed.upload_bps) / 1024.0
        downloadSpeed = Float(speed.download_bps) / 1024.0
        errorText = nil
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
            guard let namePointer = interface.ifa_name else { continue }

            let name = String(cString: namePointer)
            guard Self.isSupportedInterface(name) else { continue }

            guard let dataPointer = interface.ifa_data else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee

            let rx = UInt64(data.ifi_ibytes)
            let tx = UInt64(data.ifi_obytes)
            rxTotal = min(UInt64.max, rxTotal &+ rx)
            txTotal = min(UInt64.max, txTotal &+ tx)
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
            launchAtLoginErrorText = nil
        } catch {
            syncLaunchAtLoginStatus()
            launchAtLoginErrorText = "开机启动设置失败"
        }
    }

    func syncLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    private static func isSupportedInterface(_ name: String) -> Bool {
        !name.hasPrefix("lo")
            && !name.hasPrefix("utun")
            && !name.hasPrefix("awdl")
            && !name.hasPrefix("bridge")
            && !name.hasPrefix("llw")
    }

}
