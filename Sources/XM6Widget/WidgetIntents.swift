import AppIntents
import WidgetKit
import XM6Shared

/// One parameterless intent per widget button rather than an intent with an
/// `AppEnum` parameter. With the enum, the widget encoded the button's action with
/// no value (the App Intents runtime couldn't resolve the enum's metadata for this
/// ad-hoc signed bundle), so every tap ran with a nil parameter and failed with
/// error 2010. An intent without parameters has nothing to encode.
protocol WidgetCommandIntent: AppIntent {
    static var command: WidgetCommand { get }
}

extension WidgetCommandIntent {
    /// Runs in the widget's process, which can't reach the headphones, so it hands
    /// the change to the app and shows it optimistically until the app confirms.
    func perform() async throws -> some IntentResult {
        if var snapshot = SharedStore.loadSnapshot(), snapshot.isConnected {
            snapshot.apply(Self.command)
            SharedStore.save(snapshot)
        }
        SharedStore.post(Self.command)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
        return .result()
    }
}

// MARK: - Noise control

struct SetNoiseCancellingIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Turn On Noise Canceling"
    static let command = WidgetCommand.setNoiseMode(.noiseCancelling)
}

struct SetAmbientSoundIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Turn On Ambient Sound"
    static let command = WidgetCommand.setNoiseMode(.ambientSound)
}

struct SetNoiseControlOffIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Turn Off Noise Control"
    static let command = WidgetCommand.setNoiseMode(.off)
}

// MARK: - Listening mode

struct SetStandardListeningIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Standard Listening Mode"
    static let command = WidgetCommand.setListeningMode(.standard)
}

struct SetBackgroundMusicIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Background Music Mode"
    static let command = WidgetCommand.setListeningMode(.backgroundMusic)
}

struct SetCinemaIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Cinema Mode"
    static let command = WidgetCommand.setListeningMode(.cinema)
}

// MARK: - Equalizer

struct SetEqualizerOffIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Turn Off Equalizer"
    static let command = WidgetCommand.setEqualizer(.off)
}

struct SetEqualizerHeavyIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Heavy Equalizer"
    static let command = WidgetCommand.setEqualizer(.heavy)
}

struct SetEqualizerClearIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Clear Equalizer"
    static let command = WidgetCommand.setEqualizer(.clear)
}

struct SetEqualizerHardIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Hard Equalizer"
    static let command = WidgetCommand.setEqualizer(.hard)
}

struct SetEqualizerSoftIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Soft Equalizer"
    static let command = WidgetCommand.setEqualizer(.soft)
}

struct SetEqualizerCustomIntent: WidgetCommandIntent {
    static let title: LocalizedStringResource = "Use Custom Equalizer"
    static let command = WidgetCommand.setEqualizer(.custom)
}
