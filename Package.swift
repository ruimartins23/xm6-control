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
        )
    ]
)
