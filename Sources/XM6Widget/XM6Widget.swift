import SwiftUI
import WidgetKit
import AppIntents
import XM6Shared

@main
struct XM6WidgetBundle: WidgetBundle {
    var body: some Widget {
        HeadphonesWidget()
    }
}

struct HeadphonesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.widgetKind, provider: SnapshotProvider()) { entry in
            HeadphonesWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("XM6 Headphones")
        .description("Battery, noise control, listening mode and equalizer for your WH-1000XM6.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: HeadphonesSnapshot
}

/// The app reloads the timeline whenever the headphones change, so a single entry
/// with no refresh schedule is enough. Nothing polls.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (SharedStore.loadSnapshot() ?? .disconnected)
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SharedStore.loadSnapshot() ?? .disconnected)
        completion(Timeline(entries: [entry], policy: .never))
    }
}
