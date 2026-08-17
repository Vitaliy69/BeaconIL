// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "BeaconILMath",
    defaultLocalization: "en",
    targets: [
        .target(
            name: "BeaconILMath",
            path: "BeaconIL",
            sources: ["LMAMath.swift"]
        ),
        .executableTarget(
            name: "beaconil-tests",
            dependencies: ["BeaconILMath"],
            path: "Tests",
            sources: ["main.swift"]
        )
    ]
)
