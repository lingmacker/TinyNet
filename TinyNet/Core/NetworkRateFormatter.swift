import Foundation

func formatNetworkRate(_ bytesPerSecond: UInt64) -> String {
    let units = ["KB/s", "MB/s", "GB/s", "TB/s", "PB/s", "EB/s"]
    var value = Double(bytesPerSecond) / 1_024
    var index = 0
    while value >= 1_024 && index < units.count - 1 {
        value /= 1_024
        index += 1
    }
    return String(format: "%.2f %@", value, units[index])
}

func networkRateBarLength(downloadBps: UInt64, uploadBps: UInt64, maximumBps: Double) -> Double {
    guard maximumBps > 0 else { return 0 }
    let total = Double(downloadBps) + Double(uploadBps)
    // Square-root scaling keeps small transfers visible without changing their numeric rates.
    return min(1, total / maximumBps).squareRoot()
}
