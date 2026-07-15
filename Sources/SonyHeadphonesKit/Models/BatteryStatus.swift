import Foundation

public struct BatteryStatus: Equatable, Sendable {
    /// 0...100
    public var level: Int
    public var isCharging: Bool

    public init(level: Int, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}
