import Foundation

struct InterfaceCounters: Equatable, Sendable {
    let name: String
    let rxBytes: UInt64
    let txBytes: UInt64
}

struct NetSample: Equatable, Sendable {
    let timestampMs: Int64
    let interfaces: [InterfaceCounters]
}

struct NetSpeed: Equatable, Sendable {
    let downloadBps: UInt64
    let uploadBps: UInt64
}
