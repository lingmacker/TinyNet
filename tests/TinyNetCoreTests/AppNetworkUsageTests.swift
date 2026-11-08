import Foundation
import Darwin
import Testing
@testable import TinyNetCore

private let browser = NetworkApplication(id: "/Applications/Browser.app", name: "Browser", bundlePath: "/Applications/Browser.app")
private let mail = NetworkApplication(id: "/Applications/Mail.app", name: "Mail", bundlePath: "/Applications/Mail.app")

private func process(
    _ pid: Int32, _ rx: UInt64, _ tx: UInt64,
    start: UInt64 = 1, app: NetworkApplication = browser
) -> ProcessNetworkSample {
    ProcessNetworkSample(
        counter: ProcessNetworkCounter(pid: pid, name: "helper", receivedBytes: rx, sentBytes: tx),
        startSeconds: start, startMicroseconds: 0, application: app
    )
}

@Test("Parses truncated names with dots, spaces and unescaped commas from the final PID suffix")
func parsesNetTopProcessNames() throws {
    let rows = try parseNetTop("""
    ,bytes_in,bytes_out,
    com.apple.WebKi.923,1779,3724,
    Code Helper.927,113629,15454,
    My,App.Helper.42,18446744073709551615,0,
    """)
    #expect(rows.map(\.pid) == [923, 927, 42])
    #expect(rows.map(\.name) == ["com.apple.WebKi", "Code Helper", "My,App.Helper"])
    #expect(rows.last?.receivedBytes == UInt64.max)
}

@Test("Uses header column names and the latest complete snapshot")
func parsesNetTopHeaders() throws {
    let rows = try parseNetTop("""
    ,bytes_in,bytes_out,
    first.1,10,20,
    ,bytes_out,bytes_in,
    last.2,30,40,
    """)
    #expect(rows == [ProcessNetworkCounter(pid: 2, name: "last", receivedBytes: 40, sentBytes: 30)])
    #expect(try parseNetTop(",bytes_in,bytes_out,\n").isEmpty)
}

@Test("Rejects bad output instead of reporting it as zero traffic", arguments: [
    "", "permission denied", ",bytes_in,\n", "name.1,1,2,\n",
    ",bytes_in,bytes_out,\nname.bad,1,2,", ",bytes_in,bytes_out,\nname.0,1,2,",
    ",bytes_in,bytes_out,\nname.1,-1,2,", ",bytes_in,bytes_out,\nname.1,1,NaN,",
    ",bytes_in,bytes_out,\nname.1,18446744073709551616,2,",
    ",bytes_in,bytes_out,\nname.1,1,2,\nname.1,3,4,"
])
func rejectsInvalidNetTop(_ text: String) {
    #expect(throws: NetTopParseError.self) { try parseNetTop(text) }
}

@Test("Baselines first samples and sums helper deltas before grouping by app")
func groupsProcessDeltas() throws {
    var calculator = AppNetworkCalculator()
    let first = calculator.push([process(1, 1_000, 2_000), process(2, 3_000, 4_000)], timestampMs: 1_000)
    #expect(first.count == 1)
    #expect(first[0].totalBytes == 0)
    let second = calculator.push([process(1, 2_000, 2_500), process(2, 6_000, 5_500)], timestampMs: 3_000)
    #expect(second[0].downloadBps == 2_000)
    #expect(second[0].uploadBps == 1_000)
    #expect(second[0].receivedBytes == 4_000)
    #expect(second[0].sentBytes == 2_000)
    let third = calculator.push([process(1, 3_000, 3_000)], timestampMs: 4_000)
    #expect(third[0].downloadBps == 1_000)
    #expect(third[0].totalBytes == 7_500)
    let idle = calculator.push([], timestampMs: 5_000)
    #expect(idle[0].totalBps == 0)
    #expect(idle[0].totalBytes == 7_500)
}

@Test("New, returning and recycled PIDs cannot inject historical traffic")
func baselinesNewProcessIdentities() {
    var calculator = AppNetworkCalculator()
    _ = calculator.push([process(1, 100, 100)], timestampMs: 1_000)
    let new = calculator.push([process(1, 200, 200), process(2, 9_000, 9_000)], timestampMs: 2_000)
    #expect(new[0].totalBytes == 200)
    let reused = calculator.push([process(1, 99_000, 99_000, start: 2)], timestampMs: 3_000)
    #expect(reused[0].totalBps == 0)
    #expect(reused[0].totalBytes == 200)
    _ = calculator.push([], timestampMs: 4_000)
    let returned = calculator.push([process(1, 199_000, 199_000, start: 2)], timestampMs: 5_000)
    #expect(returned[0].totalBytes == 200)
}

@Test("Counter reset and attribution change do not cause spikes")
func handlesCounterResetAndAttributionChange() {
    var calculator = AppNetworkCalculator()
    _ = calculator.push([process(1, 1_000, 1_000)], timestampMs: 1_000)
    let reset = calculator.push([process(1, 100, 1_500)], timestampMs: 2_000)
    #expect(reset[0].downloadBps == 0)
    #expect(reset[0].uploadBps == 500)
    let moved = calculator.push([process(1, 10_000, 10_000, app: mail)], timestampMs: 3_000)
    #expect(moved.allSatisfy { $0.totalBps == 0 })
    #expect(moved.first { $0.id == browser.id }?.totalBytes == 500)
    #expect(moved.first { $0.id == mail.id }?.totalBytes == 0)
}

@Test("Failure invalidates baselines but retains session totals")
func preservesTotalsAcrossFailure() {
    var calculator = AppNetworkCalculator()
    _ = calculator.push([process(1, 100, 100)], timestampMs: 1_000)
    _ = calculator.push([process(1, 200, 300)], timestampMs: 2_000)
    calculator.invalidateBaseline()
    let recovered = calculator.push([process(1, 5_000, 5_000)], timestampMs: 9_000)
    #expect(recovered[0].totalBytes == 300)
    #expect(recovered[0].totalBps == 0)
}

@Test("Saturates per-app arithmetic and sorts by current traffic")
func clampsAppOverflowAndSorts() {
    var calculator = AppNetworkCalculator()
    _ = calculator.push([process(1, 0, 0), process(2, 0, 0), process(3, 0, 0, app: mail)], timestampMs: 1_000)
    let values = calculator.push([
        process(1, .max, .max), process(2, 1, 1), process(3, 1, 1, app: mail)
    ], timestampMs: 2_000)
    #expect(values[0].id == browser.id)
    #expect(values[0].receivedBytes == .max)
    #expect(values[0].totalBytes == .max)
    #expect(values[0].totalBps == .max)
}

@Test("Reads start time of root-owned processes without elevated privileges")
func readsRootProcessIdentity() throws {
    let identities = ProcessNetworkIdentities()
    let info = try #require(identities.info(for: 1))
    #expect(info.kp_proc.p_pid == 1)
    #expect(info.kp_proc.p_un.__p_starttime.tv_sec > 0)
    #expect(identities.info(for: getpid())?.kp_proc.p_pid == getpid())
}

@Test("System nettop sampling completes without blocking the caller", .enabled(if: ProcessInfo.processInfo.environment["TINYNET_LIVE_TESTS"] == "1"))
func samplesSystemNetTop() async throws {
    let monitor = AppNetworkMonitor()
    let start = ProcessInfo.processInfo.systemUptime
    let result = await withCheckedContinuation { continuation in
        monitor.sample { continuation.resume(returning: $0) }
    }
    let values = try result.get()
    #expect(ProcessInfo.processInfo.systemUptime - start < 5)
    #expect(values.allSatisfy { $0.totalBytes == 0 && $0.totalBps == 0 })
    let next = await withCheckedContinuation { continuation in
        monitor.sample { continuation.resume(returning: $0) }
    }
    #expect(throws: Never.self) { try next.get() }
}
