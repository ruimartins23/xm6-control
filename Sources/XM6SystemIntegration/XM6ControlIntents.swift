import AppIntents

public struct OpenXM6ControlsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open XM6 Controls"
    public static let description = IntentDescription("Open the complete XM6 control panel.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        XM6SystemActionMailbox.submit(.openControls)
        return .result()
    }
}

public struct OpenXM6WidgetIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open XM6 Widget"
    public static let description = IntentDescription("Open the floating XM6 desktop widget.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        XM6SystemActionMailbox.submit(.openWidget)
        return .result()
    }
}

public struct EnableXM6NoiseCancellingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Enable XM6 Noise Cancelling"
    public static let description = IntentDescription("Switch the XM6 to noise cancelling mode.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        XM6SystemActionMailbox.submit(.noiseCancelling)
        return .result()
    }
}

public struct EnableXM6AmbientSoundIntent: AppIntent {
    public static let title: LocalizedStringResource = "Enable XM6 Ambient Sound"
    public static let description = IntentDescription("Switch the XM6 to ambient sound mode.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        XM6SystemActionMailbox.submit(.ambientSound)
        return .result()
    }
}

public struct DisableXM6SoundControlIntent: AppIntent {
    public static let title: LocalizedStringResource = "Disable XM6 Sound Control"
    public static let description = IntentDescription("Turn off XM6 noise cancelling and ambient sound.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        XM6SystemActionMailbox.submit(.soundControlOff)
        return .result()
    }
}
