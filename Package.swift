// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aurify",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Aurify",
            targets: ["Aurify"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Aurify",
            path: ".",
            exclude: ["Info.plist"],
            sources: [
                "AurifyApp.swift",
                "Models",
                "Services",
                "ViewModels",
                "Views"
            ]
        )
    ]
)
