import Foundation

/// Actions exposed outside the app by menu-bar and Control Center entry points.
/// The raw value is persisted briefly so an action survives app process startup.
public enum XM6SystemAction: String, CaseIterable, Sendable {
    case openControls
    case openWidget
    case noiseCancelling
    case ambientSound
    case soundControlOff
}

/// Single-slot mailbox used while macOS launches or resumes the containing app for
/// an App Intent. A newer user action supersedes an older unhandled action.
public struct XM6SystemActionStore {
    public static let defaultKey = "pendingXM6SystemAction"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func submit(_ action: XM6SystemAction) {
        defaults.set(action.rawValue, forKey: key)
    }

    public func consume() -> XM6SystemAction? {
        guard let rawValue = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return XM6SystemAction(rawValue: rawValue)
    }
}

public enum XM6SystemActionMailbox {
    public static let didSubmit = Notification.Name("XM6SystemActionMailbox.didSubmit")

    public static func submit(
        _ action: XM6SystemAction,
        store: XM6SystemActionStore = XM6SystemActionStore()
    ) {
        store.submit(action)
        NotificationCenter.default.post(name: didSubmit, object: nil)
    }

    public static func consume(
        store: XM6SystemActionStore = XM6SystemActionStore()
    ) -> XM6SystemAction? {
        store.consume()
    }
}
