import Foundation

enum InterfaceFilterRule: Equatable, Sendable {
    case includeOnly([String])
    case exclude([String])
    case excludeLoopbackAndVirtual

    func allows(_ name: String) -> Bool {
        switch self {
        case let .includeOnly(allowed):
            allowed.contains(name)
        case let .exclude(blocked):
            !blocked.contains(name)
        case .excludeLoopbackAndVirtual:
            !Self.isVirtualOrLoopback(name)
        }
    }

    private static func isVirtualOrLoopback(_ name: String) -> Bool {
        name.hasPrefix("lo")
            || name.hasPrefix("utun")
            || name.hasPrefix("awdl")
            || name.hasPrefix("bridge")
            || name.hasPrefix("llw")
    }
}
