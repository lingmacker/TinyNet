import Testing
@testable import TinyNetCore

private func sample(_ timestampMs: Int64, _ interfaces: [(String, UInt64, UInt64)]) -> NetSample {
    NetSample(
        timestampMs: timestampMs,
        interfaces: interfaces.map { name, rxBytes, txBytes in
            InterfaceCounters(name: name, rxBytes: rxBytes, txBytes: txBytes)
        }
    )
}

@Test("First sample returns zero speed")
func firstSampleReturnsZeroSpeed() {
    let current = sample(1_000, [("en0", 1_000, 2_000)])

    let speed = computeSpeed(previous: nil, current: current, rule: .excludeLoopbackAndVirtual)

    #expect(speed.downloadBps == 0)
    #expect(speed.uploadBps == 0)
}

@Test("Computes speed from delta bytes over elapsed time")
func computesSpeedFromDeltaBytesOverElapsedTime() {
    let previous = sample(1_000, [("en0", 1_000, 2_000)])
    let current = sample(3_000, [("en0", 5_000, 6_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .excludeLoopbackAndVirtual)

    #expect(speed.downloadBps == 2_000)
    #expect(speed.uploadBps == 2_000)
}

@Test("Clamps negative delta to zero on counter decrease")
func clampsNegativeDeltaToZeroOnCounterDecrease() {
    let previous = sample(1_000, [("en0", 10_000, 10_000)])
    let current = sample(2_000, [("en0", 1_000, 12_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .excludeLoopbackAndVirtual)

    #expect(speed.downloadBps == 0)
    #expect(speed.uploadBps == 2_000)
}

@Test("Returns zero speed when elapsed time is zero or negative")
func returnsZeroSpeedWhenElapsedTimeIsZeroOrNegative() {
    let previous = sample(2_000, [("en0", 1_000, 2_000)])
    let currentSame = sample(2_000, [("en0", 5_000, 6_000)])
    let currentOlder = sample(1_500, [("en0", 5_000, 6_000)])

    let speedSame = computeSpeed(previous: previous, current: currentSame, rule: .excludeLoopbackAndVirtual)
    let speedOlder = computeSpeed(previous: previous, current: currentOlder, rule: .excludeLoopbackAndVirtual)

    #expect(speedSame.downloadBps == 0)
    #expect(speedSame.uploadBps == 0)
    #expect(speedOlder.downloadBps == 0)
    #expect(speedOlder.uploadBps == 0)
}

@Test("Filters virtual interfaces before aggregation")
func filtersVirtualInterfacesBeforeAggregation() {
    let previous = sample(1_000, [
        ("en0", 1_000, 1_000),
        ("lo0", 100_000, 100_000),
        ("utun2", 50_000, 50_000),
        ("awdl0", 30_000, 30_000),
        ("bridge0", 20_000, 20_000),
        ("llw0", 10_000, 10_000),
    ])
    let current = sample(2_000, [
        ("en0", 2_000, 3_000),
        ("lo0", 200_000, 200_000),
        ("utun2", 60_000, 60_000),
        ("awdl0", 40_000, 40_000),
        ("bridge0", 30_000, 30_000),
        ("llw0", 20_000, 20_000),
    ])

    let speed = computeSpeed(previous: previous, current: current, rule: .excludeLoopbackAndVirtual)

    #expect(speed.downloadBps == 1_000)
    #expect(speed.uploadBps == 2_000)
}

@Test("Include only rule filters interfaces")
func includeOnlyRuleFiltersInterfaces() {
    let previous = sample(1_000, [("en0", 1_000, 1_000), ("en1", 2_000, 2_000)])
    let current = sample(2_000, [("en0", 3_000, 4_000), ("en1", 7_000, 8_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .includeOnly(["en1"]))

    #expect(speed.downloadBps == 5_000)
    #expect(speed.uploadBps == 6_000)
}

@Test("Exclude rule filters interfaces")
func excludeRuleFiltersInterfaces() {
    let previous = sample(1_000, [("en0", 1_000, 1_000), ("en1", 2_000, 2_000)])
    let current = sample(2_000, [("en0", 3_000, 4_000), ("en1", 7_000, 8_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .exclude(["en1"]))

    #expect(speed.downloadBps == 2_000)
    #expect(speed.uploadBps == 3_000)
}

@Test("All interfaces filtered out returns zero")
func allInterfacesFilteredOutReturnsZero() {
    let previous = sample(1_000, [("lo0", 1_000, 1_000)])
    let current = sample(2_000, [("lo0", 5_000, 7_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .includeOnly(["en0"]))

    #expect(speed.downloadBps == 0)
    #expect(speed.uploadBps == 0)
}

@Test("Missing interface in current sample contributes no delta")
func missingInterfaceInCurrentSampleContributesNoDelta() {
    let previous = sample(1_000, [("en0", 1_000, 1_000), ("en1", 2_000, 2_000)])
    let current = sample(2_000, [("en0", 2_500, 3_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .includeOnly(["en0", "en1"]))

    #expect(speed.downloadBps == 1_500)
    #expect(speed.uploadBps == 2_000)
}

@Test("New interface in current sample contributes zero delta")
func newInterfaceInCurrentSampleContributesZeroDelta() {
    let previous = sample(1_000, [("en0", 1_000, 1_000)])
    let current = sample(2_000, [("en0", 2_000, 3_000), ("en1", 8_000, 9_000)])

    let speed = computeSpeed(previous: previous, current: current, rule: .includeOnly(["en0", "en1"]))

    #expect(speed.downloadBps == 1_000)
    #expect(speed.uploadBps == 2_000)
}

@Test("Saturates aggregate delta on overflow")
func saturatesAggregateDeltaOnOverflow() {
    let previous = sample(1_000, [("en0", 0, 0), ("en1", 0, 0)])
    let current = sample(2_000, [("en0", UInt64.max, 10), ("en1", 1, 20)])

    let speed = computeSpeed(previous: previous, current: current, rule: .includeOnly(["en0", "en1"]))

    #expect(speed.downloadBps == UInt64.max)
    #expect(speed.uploadBps == 30)
}

@Test("Calculator reset clears previous sample")
func calculatorResetClearsPreviousSample() {
    let calculator = NetSpeedCalculator()

    let first = calculator.pushTotals(timestampMs: 1_000, rxBytes: 1_000, txBytes: 2_000)
    let second = calculator.pushTotals(timestampMs: 2_000, rxBytes: 3_000, txBytes: 5_000)
    calculator.reset()
    let afterReset = calculator.pushTotals(timestampMs: 3_000, rxBytes: 7_000, txBytes: 11_000)

    #expect(first.downloadBps == 0)
    #expect(first.uploadBps == 0)
    #expect(second.downloadBps == 2_000)
    #expect(second.uploadBps == 3_000)
    #expect(afterReset.downloadBps == 0)
    #expect(afterReset.uploadBps == 0)
}
