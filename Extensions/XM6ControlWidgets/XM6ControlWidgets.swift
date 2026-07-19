import SwiftUI
import WidgetKit
import XM6SystemIntegration

#if compiler(>=6.2)
@main
struct XM6ControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        XM6OpenControlsControl()
        XM6OpenWidgetControl()
        XM6NoiseCancellingControl()
        XM6AmbientSoundControl()
        XM6SoundControlOffControl()
    }
}

struct XM6OpenControlsControl: ControlWidget {
    static let kind = "com.local.xm6control.controls.open"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenXM6ControlsIntent()) {
                Label("XM6 Controls", systemImage: "headphones")
            }
        }
        .displayName("XM6 Controls")
        .description("Open all controls for the Sony WH-1000XM6.")
    }
}

struct XM6OpenWidgetControl: ControlWidget {
    static let kind = "com.local.xm6control.widget.open"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenXM6WidgetIntent()) {
                Label("XM6 Widget", systemImage: "macwindow.on.rectangle")
            }
        }
        .displayName("XM6 Widget")
        .description("Open the floating XM6 desktop widget.")
    }
}

struct XM6NoiseCancellingControl: ControlWidget {
    static let kind = "com.local.xm6control.sound.noise-cancelling"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: EnableXM6NoiseCancellingIntent()) {
                Label("Noise Cancelling", systemImage: "person.wave.2.fill")
            }
        }
        .displayName("XM6 Noise Cancelling")
        .description("Switch the XM6 to noise cancelling mode.")
    }
}

struct XM6AmbientSoundControl: ControlWidget {
    static let kind = "com.local.xm6control.sound.ambient"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: EnableXM6AmbientSoundIntent()) {
                Label("Ambient Sound", systemImage: "waveform.and.person.filled")
            }
        }
        .displayName("XM6 Ambient Sound")
        .description("Switch the XM6 to ambient sound mode.")
    }
}

struct XM6SoundControlOffControl: ControlWidget {
    static let kind = "com.local.xm6control.sound.off"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DisableXM6SoundControlIntent()) {
                Label("Sound Control Off", systemImage: "speaker.slash.fill")
            }
        }
        .displayName("XM6 Sound Control Off")
        .description("Turn off XM6 noise cancelling and ambient sound.")
    }
}
#else
/// Compile-only fallback used to validate the extension bundle with Xcode 16.
/// The release script ships this extension only when the macOS 26 SDK is active.
@main
struct XM6ControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        XM6ControlCenterUpgradeWidget()
    }
}

private struct UpgradeEntry: TimelineEntry {
    let date: Date
}

private struct UpgradeProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpgradeEntry {
        UpgradeEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (UpgradeEntry) -> Void) {
        completion(UpgradeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpgradeEntry>) -> Void) {
        completion(Timeline(entries: [UpgradeEntry(date: Date())], policy: .never))
    }
}

private struct XM6ControlCenterUpgradeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.local.xm6control.upgrade", provider: UpgradeProvider()) { _ in
            Label("XM6 Control Center requires macOS 26", systemImage: "headphones")
                .padding()
        }
        .configurationDisplayName("XM6 Controls")
        .description("Install macOS 26 to add XM6 controls to Control Center.")
        .supportedFamilies([.systemSmall])
    }
}
#endif
