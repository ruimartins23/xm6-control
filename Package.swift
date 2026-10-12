// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "XM6Control",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "SonyHeadphonesKit", targets: ["SonyHeadphonesKit"]),
        .library(name: "XM6Shared", targets: ["XM6Shared"]),
    ],
    targets: [
        .target(
            name: "SonyHeadphonesKit",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("IOBluetooth")
            ]
        ),
        // Snapshot and command mailbox shared by the app and its WidgetKit extension.
        .target(
            name: "XM6Shared",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "XM6Control",
            dependencies: ["SonyHeadphonesKit", "XM6Shared"],
            exclude: ["Resources"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Developer tool: connects to the headphones and sends raw hex payloads,
        // printing every reply. Used to verify command layouts on real hardware.
        .executableTarget(
            name: "XM6Probe",
            dependencies: ["SonyHeadphonesKit"],
            exclude: ["Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                // Embed Info.plist into the binary so the Bluetooth privacy check
                // (NSBluetoothAlwaysUsageDescription) passes for a bare CLI tool.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/XM6Probe/Info.plist"
                ])
            ]
        )
    ]
)
