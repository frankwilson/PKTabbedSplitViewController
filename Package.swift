// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "PKTabbedSplitViewController",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(name: "PKTabbedSplitViewController", targets: ["TabbedSplitViewController"]),
    ],
    targets: [
        .target(name: "TabbedSplitViewController", dependencies: []),
    ],
    swiftLanguageVersions: [.v4_2]
)
