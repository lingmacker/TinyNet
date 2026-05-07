import Foundation

func computeSpeed(
    previous: NetSample?,
    current: NetSample,
    rule: InterfaceFilterRule
) -> NetSpeed {
    guard let previous else {
        return NetSpeed(downloadBps: 0, uploadBps: 0)
    }

    let elapsedMs = current.timestampMs - previous.timestampMs
    guard elapsedMs > 0 else {
        return NetSpeed(downloadBps: 0, uploadBps: 0)
    }

    let delta = deltaBytes(previous: previous, current: current, rule: rule)
    let elapsedSeconds = Double(elapsedMs) / 1000.0
    guard elapsedSeconds > 0 else {
        return NetSpeed(downloadBps: 0, uploadBps: 0)
    }

    return NetSpeed(
        downloadBps: bytesPerSecond(deltaBytes: delta.rxBytes, elapsedSeconds: elapsedSeconds),
        uploadBps: bytesPerSecond(deltaBytes: delta.txBytes, elapsedSeconds: elapsedSeconds)
    )
}

final class NetSpeedCalculator {
    private var previous: NetSample?
    private let rule: InterfaceFilterRule

    init(rule: InterfaceFilterRule = .excludeLoopbackAndVirtual) {
        self.rule = rule
    }

    func reset() {
        previous = nil
    }

    func pushTotals(timestampMs: Int64, rxBytes: UInt64, txBytes: UInt64) -> NetSpeed {
        let current = NetSample(
            timestampMs: timestampMs,
            interfaces: [
                InterfaceCounters(name: "en0", rxBytes: rxBytes, txBytes: txBytes),
            ]
        )
        let speed = computeSpeed(previous: previous, current: current, rule: rule)
        previous = current
        return speed
    }
}

private func bytesPerSecond(deltaBytes: UInt64, elapsedSeconds: Double) -> UInt64 {
    let value = Double(deltaBytes) / elapsedSeconds
    guard value < Double(UInt64.max) else {
        return UInt64.max
    }
    return UInt64(value)
}

private func deltaBytes(
    previous: NetSample,
    current: NetSample,
    rule: InterfaceFilterRule
) -> (rxBytes: UInt64, txBytes: UInt64) {
    current.interfaces
        .filter { rule.allows($0.name) }
        .reduce((rxBytes: 0, txBytes: 0)) { result, currentInterface in
            let previousInterface = previous.interfaces.first { $0.name == currentInterface.name }
            let previousRxBytes = previousInterface?.rxBytes ?? currentInterface.rxBytes
            let previousTxBytes = previousInterface?.txBytes ?? currentInterface.txBytes

            return (
                rxBytes: result.rxBytes.saturatingAdd(
                    currentInterface.rxBytes.saturatingSubtract(previousRxBytes)
                ),
                txBytes: result.txBytes.saturatingAdd(
                    currentInterface.txBytes.saturatingSubtract(previousTxBytes)
                )
            )
        }
}

private extension UInt64 {
    func saturatingAdd(_ value: UInt64) -> UInt64 {
        let (result, overflow) = addingReportingOverflow(value)
        return overflow ? UInt64.max : result
    }

    func saturatingSubtract(_ value: UInt64) -> UInt64 {
        self >= value ? self - value : 0
    }
}
