import AppKit
import Darwin
import Foundation

final class AppNetworkMonitor {
    private let queue = DispatchQueue(label: "com.tinynet.app-network", qos: .utility)
    private var calculator = AppNetworkCalculator()

    func sample(completion: @escaping (Result<[AppNetworkUsage], Error>) -> Void) {
        queue.async { [self] in
            do {
                let output = try Self.readNetTop()
                let counters = try parseNetTop(output)
                let identities = ProcessNetworkIdentities()
                let samples = counters.compactMap { counter -> ProcessNetworkSample? in
                    guard let info = identities.info(for: counter.pid) else { return nil }
                    return ProcessNetworkSample(
                        counter: counter,
                        startSeconds: UInt64(info.kp_proc.p_un.__p_starttime.tv_sec),
                        startMicroseconds: UInt64(info.kp_proc.p_un.__p_starttime.tv_usec),
                        application: identities.application(for: counter)
                    )
                }
                let timestampMs = Int64(ProcessInfo.processInfo.systemUptime * 1_000)
                completion(.success(calculator.push(samples, timestampMs: timestampMs)))
            } catch {
                calculator.invalidateBaseline()
                completion(.failure(error))
            }
        }
    }

    private static func readNetTop() throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-n", "-P", "-L", "1", "-t", "external", "-x", "-J", "bytes_in,bytes_out"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3, execute: deadline)
        defer { deadline.cancel() }
        // Drain before waiting: a machine with many processes can fill the pipe.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) else {
            throw NetTopParseError.invalidOutput
        }
        return output
    }
}

final class ProcessNetworkIdentities {
    private var infos: [Int32: kinfo_proc] = [:]
    private var applications: [String: NetworkApplication] = [:]

    // shortcut: this private API is optional; retain bundle/parent fallbacks if macOS removes it.
    private static let responsiblePID: (@convention(c) (Int32) -> Int32)? = {
        guard let symbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid"
        ) else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (Int32) -> Int32).self)
    }()

    func info(for pid: Int32) -> kinfo_proc? {
        if let cached = infos[pid] { return cached }
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var value = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        // sysctl also exposes start times for root-owned proxies; PROC_PIDTBSDINFO does not.
        guard sysctl(&mib, UInt32(mib.count), &value, &size, nil, 0) == 0,
              size == MemoryLayout<kinfo_proc>.size, value.kp_proc.p_pid == pid,
              value.kp_proc.p_un.__p_starttime.tv_sec >= 0,
              value.kp_proc.p_un.__p_starttime.tv_usec >= 0 else { return nil }
        infos[pid] = value
        return value
    }

    func application(for counter: ProcessNetworkCounter) -> NetworkApplication {
        let path = executablePath(counter.pid)
        if let app = bundledApplication(path: path) { return app }
        if let responsible = Self.responsiblePID?(counter.pid), responsible > 1,
           responsible != counter.pid,
           let app = bundledApplication(path: executablePath(responsible)) {
            return app
        }

        var pid = counter.pid
        var visited: Set<Int32> = []
        for _ in 0..<32 {
            guard visited.insert(pid).inserted, let process = info(for: pid) else { break }
            pid = process.kp_eproc.e_ppid
            guard pid > 1 else { break }
            if let app = bundledApplication(path: executablePath(pid)) { return app }
        }
        return NetworkApplication(
            id: path ?? "process:\(counter.pid)",
            name: path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? counter.name,
            bundlePath: nil
        )
    }

    private func executablePath(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(cString: buffer) : nil
    }

    private func bundledApplication(path: String?) -> NetworkApplication? {
        guard let path else { return nil }
        let components = URL(fileURLWithPath: path).pathComponents
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let url = URL(fileURLWithPath: NSString.path(withComponents: Array(components[...index])))
        if let app = applications[url.path] { return app }
        let bundle = Bundle(url: url)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let app = NetworkApplication(id: url.path, name: name, bundlePath: url.path)
        applications[url.path] = app
        return app
    }
}
