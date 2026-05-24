// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Intake",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Intake",
            targets: ["Intake"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Intake",
            dependencies: [],
            path: "Intake"
        )
    ]
)
