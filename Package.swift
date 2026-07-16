// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "XM6Control",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "SonyHeadphonesKit",
            linkerSettings: [
                .linkedFramework("IOBluetooth")
            ]
        ),
        .executableTarget(
            name: "XM6Control",
            dependencies: ["SonyHeadphonesKit"],
            exclude: ["Resources"]
        ),
        // Developer tool: connects to the headphones and sends raw hex payloads,
        // printing every reply. Used to verify command layouts on real hardware.
        .executableTarget(
            name: "XM6Probe",
            dependencies: ["SonyHeadphonesKit"],
            exclude: ["Info.plist"],
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
