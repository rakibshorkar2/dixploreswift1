// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DirXplore",
    platforms: [
        .iOS(.v18)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "DirXplore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "DirXploreTests",
            dependencies: ["DirXplore"]
        ),
    ]
)
