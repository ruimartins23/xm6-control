import AppKit
import Combine
import Foundation
import SonyHeadphonesKit
import WidgetKit
import XM6Shared

/// Keeps the WidgetKit widget in step with the headphones: publishes a snapshot when
/// the state changes, and carries out the commands the widget's buttons post.
@MainActor
final class WidgetBridge {
    private let controller: HeadphonesController
    private var lastPublished: HeadphonesSnapshot?
    private var subscriptions: Set<AnyCancellable> = []

    init(controller: HeadphonesController) {
        self.controller = controller

        // `objectWillChange` fires before the value lands; hopping a runloop turn
        // reads the new state, and the debounce folds a burst of initial replies into
        // one widget reload. That matters because macOS grants roughly one reload per
        // five seconds while the app is in front; a second one inside that window is
        // deferred to its end.
        controller.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] in self?.publish() }
            .store(in: &subscriptions)

        // Quitting never moves the controller to disconnected, so without this the
        // widget would keep showing the last live state after the app is gone.
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { _ in
                SharedStore.save(.disconnected)
                WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
            }
            .store(in: &subscriptions)

        // A tap made while the app wasn't running is stale by now.
        _ = SharedStore.takeCommand()
        SharedStore.observeCommands { [weak self] in
            MainActor.assumeIsolated { self?.runPendingCommand() }
        }
        publish()
    }

    private func publish() {
        let snapshot = Self.snapshot(of: controller)
        // `updatedAt` always differs, so compare without it.
        var comparable = snapshot
        comparable.updatedAt = lastPublished?.updatedAt ?? snapshot.updatedAt
        guard comparable != lastPublished else { return }

        lastPublished = snapshot
        SharedStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
    }

    private func runPendingCommand() {
        guard let command = SharedStore.takeCommand() else { return }
        guard controller.connectionState == .connected else {
            // The widget showed the change optimistically; put it back.
            lastPublished = nil
            publish()
            return
        }
        switch command {
        case .setNoiseMode(let mode):
            var state = controller.ambientSound ?? AmbientSoundState()
            state.mode = AmbientSoundMode(mode)
            controller.setAmbientSound(state)
        case .setListeningMode(let mode):
            controller.setListeningMode(ListeningMode(mode))
        case .setEqualizer(let preset):
            controller.setEqualizerPreset(EqualizerPreset(preset))
        }
    }

    private static func snapshot(of controller: HeadphonesController) -> HeadphonesSnapshot {
        guard controller.connectionState == .connected else {
            return HeadphonesSnapshot(isConnected: false, deviceName: controller.deviceName ?? "WH-1000XM6")
        }
        return HeadphonesSnapshot(
            isConnected: true,
            deviceName: controller.deviceName ?? "WH-1000XM6",
            batteryLevel: controller.battery?.level,
            isCharging: controller.battery?.isCharging ?? false,
            noiseMode: controller.ambientSound.map { NoiseMode($0.mode) },
            listeningMode: controller.listeningMode.map(ListeningModeOption.init),
            equalizer: controller.equalizer?.preset.map(EqualizerOption.init),
            equalizerLabel: controller.equalizer.map { $0.preset?.label ?? "Personalized" },
            playingOn: controller.devices?.first(where: \.isPlayback)?.name
        )
    }
}

extension NoiseMode {
    init(_ mode: AmbientSoundMode) {
        switch mode {
        case .noiseCancelling: self = .noiseCancelling
        case .ambientSound: self = .ambientSound
        case .off: self = .off
        }
    }
}

extension AmbientSoundMode {
    init(_ mode: NoiseMode) {
        switch mode {
        case .noiseCancelling: self = .noiseCancelling
        case .ambientSound: self = .ambientSound
        case .off: self = .off
        }
    }
}

extension ListeningModeOption {
    init(_ mode: ListeningMode) {
        switch mode {
        case .standard: self = .standard
        case .backgroundMusic: self = .backgroundMusic
        case .cinema: self = .cinema
        }
    }
}

extension ListeningMode {
    init(_ mode: ListeningModeOption) {
        switch mode {
        case .standard: self = .standard
        case .backgroundMusic: self = .backgroundMusic
        case .cinema: self = .cinema
        }
    }
}

extension EqualizerOption {
    init(_ preset: EqualizerPreset) {
        switch preset {
        case .off: self = .off
        case .heavy: self = .heavy
        case .clear: self = .clear
        case .hard: self = .hard
        case .soft: self = .soft
        case .custom: self = .custom
        }
    }
}

extension EqualizerPreset {
    init(_ option: EqualizerOption) {
        switch option {
        case .off: self = .off
        case .heavy: self = .heavy
        case .clear: self = .clear
        case .hard: self = .hard
        case .soft: self = .soft
        case .custom: self = .custom
        }
    }
}
