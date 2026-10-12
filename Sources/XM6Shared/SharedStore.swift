import Foundation

/// The mailbox between the app and its widget: the app writes the snapshot, the widget
/// writes commands, and a Darwin notification wakes the app when one lands.
///
/// A folder in Application Support rather than an app-group container. Without a
/// paid developer team the app is signed ad hoc, and macOS then refuses the
/// unsandboxed app access to a group container the sandboxed widget owns. The widget
/// reaches this folder through a sandbox file exception in its entitlements instead.
public enum SharedStore {
    public static let widgetKind = "XM6HeadphonesWidget"

    private static let commandNotification = "com.local.xm6control.widget-command" as CFString

    /// The real home folder: inside the widget's sandbox `NSHomeDirectory()` points at
    /// its container, which the app can't see.
    private static let directory: URL? = {
        guard let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home))
            .appendingPathComponent("Library/Application Support/XM6 Control/Widget", isDirectory: true)
    }()

    private static func url(_ name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }

    public static func loadSnapshot() -> HeadphonesSnapshot? {
        read(HeadphonesSnapshot.self, from: "snapshot.json")
    }

    public static func save(_ snapshot: HeadphonesSnapshot) {
        write(snapshot, to: "snapshot.json")
    }

    public static func post(_ command: WidgetCommand) {
        write(command, to: "command.json")
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(commandNotification),
            nil, nil, true
        )
    }

    /// Returns and clears the pending command, so a command is executed once even if
    /// the notification is delivered more than once.
    public static func takeCommand() -> WidgetCommand? {
        let command = read(WidgetCommand.self, from: "command.json")
        if let file = url("command.json") {
            try? FileManager.default.removeItem(at: file)
        }
        return command
    }

    /// Calls `handler` on the main queue whenever the widget posts a command.
    /// The observer lives for the rest of the process.
    public static func observeCommands(_ handler: @escaping @Sendable () -> Void) {
        let box = Unmanaged.passRetained(HandlerBox(handler)).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            box,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let handler = Unmanaged<HandlerBox>.fromOpaque(observer).takeUnretainedValue().handler
                DispatchQueue.main.async(execute: handler)
            },
            commandNotification,
            nil,
            .deliverImmediately
        )
    }

    private static func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let file = url(name), let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to name: String) {
        guard let file = url(name), let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    private final class HandlerBox {
        let handler: @Sendable () -> Void
        init(_ handler: @escaping @Sendable () -> Void) { self.handler = handler }
    }
}
