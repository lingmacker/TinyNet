import Testing
@testable import TinyNetCore

@Test("Formats process network rates with two decimal places", arguments: [
    (UInt64(0), "0.00 KB/s"),
    (UInt64(1), "0.00 KB/s"),
    (UInt64(512), "0.50 KB/s"),
    (UInt64(1_023), "1.00 KB/s"),
    (UInt64(1_024), "1.00 KB/s"),
    (UInt64(1_040), "1.02 KB/s"),
    (UInt64(13 * 1_024 + 512), "13.50 KB/s"),
    (UInt64(951 * 1_024), "951.00 KB/s"),
    (UInt64(1_048_575), "1024.00 KB/s"),
    (UInt64(1_048_576), "1.00 MB/s"),
    (UInt64(5_368_709_120), "5.00 GB/s"),
    (UInt64.max, "16.00 EB/s"),
])
func formatsNetworkRatesWithTwoDecimals(bytes: UInt64, expected: String) {
    #expect(formatNetworkRate(bytes) == expected)
}

@Test("Traffic bars keep idle rows empty and small transfers visible")
func scalesNetworkRateBars() {
    #expect(networkRateBarLength(downloadBps: 0, uploadBps: 0, maximumBps: 0) == 0)
    #expect(networkRateBarLength(downloadBps: 0, uploadBps: 0, maximumBps: 1_024) == 0)
    #expect(networkRateBarLength(downloadBps: 951 * 1_024, uploadBps: 0, maximumBps: 951 * 1_024) == 1)
    let smaller = networkRateBarLength(downloadBps: 13 * 1_024, uploadBps: 10 * 1_024, maximumBps: 951 * 1_024)
    #expect(smaller > 0.15 && smaller < 0.16)
    #expect(networkRateBarLength(downloadBps: .max, uploadBps: .max, maximumBps: 1) == 1)
}
