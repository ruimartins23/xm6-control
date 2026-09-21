import Foundation

/// Tracks user activity separately from protocol traffic, which must not keep an
/// otherwise idle connection alive.
struct ConnectionUsage {
    static let gracePeriod: Duration = .seconds(20)

    var releaseWhenIdle = false
    private var visibleSurfaces: Set<UUID> = []
    private(set) var idleDeadline: ContinuousClock.Instant?
    var hasVisibleSurfaces: Bool { !visibleSurfaces.isEmpty }

    mutating func setSurface(_ id: UUID, visible: Bool, now: ContinuousClock.Instant = .now) -> Bool {
        let changed: Bool
        if visible {
            changed = visibleSurfaces.insert(id).inserted
        } else {
            changed = visibleSurfaces.remove(id) != nil
        }
        if changed { recordActivity(now: now) }
        return changed
    }

    mutating func recordActivity(now: ContinuousClock.Instant = .now) {
        idleDeadline = releaseWhenIdle && visibleSurfaces.isEmpty
            ? now.advanced(by: Self.gracePeriod) : nil
    }

    func shouldRelease(now: ContinuousClock.Instant = .now) -> Bool {
        releaseWhenIdle && idleDeadline.map { now >= $0 } == true
    }
}
