import SwiftUI
import AppKit
import SonyHeadphonesKit

/// A named equalizer curve kept by the app.
///
/// The headphones store exactly one custom curve. Profiles live here instead, and
/// applying one writes its curve into that single slot, so there is no limit on how
/// many you keep and nothing on the headphones has to change to support them.
struct EqualizerProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// Gain per band, low frequency first, in the range the headphones accept.
    var bands: [Int]
}

@MainActor
final class EqualizerProfileStore: ObservableObject {
    private static let storageKey = "equalizerProfiles"
    private static let seededKey = "equalizerProfilesSeeded"

    @Published private(set) var profiles: [EqualizerProfile] = []

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([EqualizerProfile].self, from: data) {
            profiles = decoded.map { Self.sanitised($0) }
        } else if !defaults.bool(forKey: Self.seededKey) {
            // Starters only on a first run. Once someone deletes them they stay
            // deleted, rather than reappearing on the next launch.
            profiles = Self.starters
            persist()
        }
        defaults.set(true, forKey: Self.seededKey)
    }

    // MARK: - Queries

    /// The saved profile whose curve is exactly the one given, if any. This is how
    /// the interface knows which profile is "on" without storing a selection that
    /// could drift from what the headphones actually report.
    func profile(matching bands: [Int]) -> EqualizerProfile? {
        guard bands.count == SonyCommands.defaultBandCount else { return nil }
        return profiles.first { $0.bands == bands }
    }

    /// What to call the equalizer's current state: a Sony preset, a saved profile
    /// whose curve is loaded in the custom slot, plain "Custom", or "Personalized"
    /// for a preset id the app doesn't recognise.
    func displayName(for state: EqualizerState?) -> String {
        guard let state else { return EqualizerPreset.off.label }
        if state.presetCode == EqualizerPreset.custom.rawValue,
           let match = profile(matching: state.bands) {
            return match.name
        }
        return state.preset?.label ?? "Personalized"
    }

    // MARK: - Changes

    @discardableResult
    func add(name: String, bands: [Int]) -> EqualizerProfile {
        let profile = Self.sanitised(EqualizerProfile(id: UUID(), name: uniqueName(name), bands: bands))
        profiles.append(profile)
        persist()
        return profile
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = uniqueName(name, excluding: id)
        persist()
    }

    func overwrite(_ id: UUID, with bands: [Int]) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index] = Self.sanitised(EqualizerProfile(id: id, name: profiles[index].name, bands: bands))
        persist()
    }

    func delete(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Storage

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// "Bass Boost" twice in a menu is ambiguous, so a repeated name gets a number.
    private func uniqueName(_ proposed: String, excluding id: UUID? = nil) -> String {
        let base = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(profiles.filter { $0.id != id }.map(\.name))
        guard taken.contains(base) else { return base }
        var counter = 2
        while taken.contains("\(base) \(counter)") { counter += 1 }
        return "\(base) \(counter)"
    }

    /// Forces a curve into the shape the headphones accept: exactly ten bands, each
    /// inside the gain range. Guards against a hand-edited or older stored value
    /// producing a write the firmware would reject.
    private static func sanitised(_ profile: EqualizerProfile) -> EqualizerProfile {
        let count = SonyCommands.defaultBandCount
        let range = SonyCommands.bandGainRange
        var bands = Array(profile.bands.prefix(count))
        bands += Array(repeating: 0, count: max(0, count - bands.count))
        bands = bands.map { min(max($0, range.lowerBound), range.upperBound) }
        return EqualizerProfile(id: profile.id, name: profile.name, bands: bands)
    }

    /// Starting points so the feature is useful before anything has been saved.
    /// Shaped by band position only: the headphones don't document the centre
    /// frequency of each band, so these are broad tilts rather than tuned curves.
    private static let starters: [EqualizerProfile] = [
        EqualizerProfile(id: UUID(), name: "Bass Boost", bands: [5, 4, 3, 1, 0, 0, 0, 0, 0, 0]),
        EqualizerProfile(id: UUID(), name: "Vocal", bands: [-2, -1, 0, 2, 3, 3, 2, 0, -1, -1]),
        EqualizerProfile(id: UUID(), name: "Treble Boost", bands: [0, 0, 0, 0, 0, 0, 1, 3, 4, 5]),
    ]
}

/// Native prompts for naming and deleting profiles.
///
/// `NSAlert` rather than a SwiftUI sheet: a sheet needs view-local presentation state,
/// and `@State` cannot compile against the Command Line Tools this project builds
/// with. An alert with a text field is also exactly how macOS asks for a name.
@MainActor
enum ProfilePrompt {
    /// Asks for a name. Returns nil when cancelled; an empty entry falls back to the
    /// suggested name rather than saving a profile with no label.
    static func askForName(title: String, message: String, suggested: String, confirm: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = suggested
        field.placeholderString = suggested
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? suggested : name
    }

    static func confirmDelete(_ name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete \u{201c}\(name)\u{201d}?"
        alert.informativeText = "The profile is removed from this Mac. The curve currently on the headphones is not changed."
        alert.alertStyle = .warning
        let delete = alert.addButton(withTitle: "Delete")
        delete.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
