import Foundation

struct ProcessNetworkCounter: Equatable {
    let pid: Int32
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

enum NetTopParseError: Error {
    case invalidOutput
}

func parseNetTop(_ output: String) throws -> [ProcessNetworkCounter] {
    var header: [String]?
    var result: [ProcessNetworkCounter] = []

    for line in output.split(whereSeparator: \.isNewline) {
        var fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        if fields.last == "" { fields.removeLast() }
        if fields.first == "" {
            guard fields.contains("bytes_in"), fields.contains("bytes_out") else {
                throw NetTopParseError.invalidOutput
            }
            header = fields
            result.removeAll(keepingCapacity: true)
            continue
        }
        guard let header, fields.count >= header.count,
              let rxIndex = header.firstIndex(of: "bytes_in"),
              let txIndex = header.firstIndex(of: "bytes_out") else {
            throw NetTopParseError.invalidOutput
        }
        // nettop does not escape commas in process names; numeric columns are right-aligned.
        let extraFields = fields.count - header.count
        let process = fields.prefix(extraFields + 1).joined(separator: ",")
        guard let dot = process.lastIndex(of: "."),
              let pid = Int32(process[process.index(after: dot)...]), pid > 0,
              let rx = UInt64(fields[rxIndex + extraFields].trimmingCharacters(in: .whitespaces)),
              let tx = UInt64(fields[txIndex + extraFields].trimmingCharacters(in: .whitespaces)) else {
            throw NetTopParseError.invalidOutput
        }
        result.append(ProcessNetworkCounter(
            pid: pid, name: String(process[..<dot]), receivedBytes: rx, sentBytes: tx
        ))
    }
    guard header != nil, Set(result.map(\.pid)).count == result.count else {
        throw NetTopParseError.invalidOutput
    }
    return result
}

struct NetworkApplication: Equatable, Sendable {
    let id: String
    let name: String
    let bundlePath: String?
}

struct ProcessNetworkSample {
    let counter: ProcessNetworkCounter
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let application: NetworkApplication
}

struct AppNetworkUsage: Identifiable, Sendable {
    let application: NetworkApplication
    var downloadBps: UInt64 = 0
    var uploadBps: UInt64 = 0
    var receivedBytes: UInt64 = 0
    var sentBytes: UInt64 = 0

    var id: String { application.id }
    var totalBytes: UInt64 { receivedBytes.addingClamped(sentBytes) }
    var totalBps: UInt64 { downloadBps.addingClamped(uploadBps) }
}

struct AppNetworkCalculator {
    private struct Previous {
        let sample: ProcessNetworkSample
        let timestampMs: Int64
    }

    private var previous: [Int32: Previous] = [:]
    private var applications: [String: AppNetworkUsage] = [:]

    mutating func push(_ samples: [ProcessNetworkSample], timestampMs: Int64) -> [AppNetworkUsage] {
        for id in Array(applications.keys) {
            applications[id]?.downloadBps = 0
            applications[id]?.uploadBps = 0
        }
        var next: [Int32: Previous] = [:]
        for sample in samples {
            let current = sample.counter
            next[current.pid] = Previous(sample: sample, timestampMs: timestampMs)
            let app = sample.application
            var usage = applications[app.id] ?? AppNetworkUsage(application: app)
            if let old = previous[current.pid],
               old.sample.startSeconds == sample.startSeconds,
               old.sample.startMicroseconds == sample.startMicroseconds,
               old.sample.application.id == app.id,
               timestampMs > old.timestampMs {
                let rx = current.receivedBytes >= old.sample.counter.receivedBytes
                    ? current.receivedBytes - old.sample.counter.receivedBytes : 0
                let tx = current.sentBytes >= old.sample.counter.sentBytes
                    ? current.sentBytes - old.sample.counter.sentBytes : 0
                let calculator = NetSpeedCalculator()
                _ = calculator.pushTotals(NetTotalsSample(
                    timestampMs: old.timestampMs, rxBytes: 0, txBytes: 0
                ))
                let rate = calculator.pushTotals(NetTotalsSample(
                    timestampMs: timestampMs, rxBytes: rx, txBytes: tx
                ))
                usage.downloadBps = usage.downloadBps.addingClamped(rate.downloadBps)
                usage.uploadBps = usage.uploadBps.addingClamped(rate.uploadBps)
                usage.receivedBytes = usage.receivedBytes.addingClamped(rx)
                usage.sentBytes = usage.sentBytes.addingClamped(tx)
            }
            applications[app.id] = usage
        }
        previous = next
        return applications.values.sorted {
            if $0.totalBps != $1.totalBps { return $0.totalBps > $1.totalBps }
            if $0.totalBytes != $1.totalBytes { return $0.totalBytes > $1.totalBytes }
            return $0.id < $1.id
        }
    }

    mutating func invalidateBaseline() {
        previous.removeAll()
    }
}

private extension UInt64 {
    func addingClamped(_ other: UInt64) -> UInt64 {
        let (sum, overflow) = addingReportingOverflow(other)
        return overflow ? .max : sum
    }
}
