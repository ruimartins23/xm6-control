import Foundation

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case searching
    case connecting
    case initializing
    case connected
    case failed(String)
}

public enum ProtocolVersion: Equatable, Sendable {
    case v1
    case v2
    case unknown
}
