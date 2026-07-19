// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "XM6Control",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SonyHeadphonesKit", targets: ["SonyHeadphonesKit"]),
        .library(name: "XM6SystemIntegration", targets: ["XM6SystemIntegration"]),
        .executable(name: "XM6Control", targets: ["XM6Control"]),
        .executable(name: "XM6Probe", targets: ["XM6Probe"])
    ],
    targets: [
        .target(
            name: "SonyHeadphonesKit",
            linkerSettings: [
                .linkedFramework("IOBluetooth")
            ]
        ),
        .target(name: "XM6SystemIntegration"),
        .executableTarget(
            name: "XM6Control",
            dependencies: ["SonyHeadphonesKit", "XM6SystemIntegration"],
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
        ),
        .testTarget(
            name: "XM6SystemIntegrationTests",
            dependencies: ["XM6SystemIntegration"]
        )
    ]
)
