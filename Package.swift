// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aurify",
    platforms: [.iOS("26.0")],
    products: [.executable(name: "Aurify", targets: ["Aurify"])],
    targets: [
        .executableTarget(
            name: "Aurify",
            path: ".",
            exclude: [
                ".git", ".github", "Aurify.xcodeproj", "Aurify-iOS-v1.0.0.ipa",
                "Fixed_IPA", "README.md", "Info.plist", "PrivacyInfo.xcprivacy", "Assets.xcassets"
            ],
            sources: ["AurifyApp.swift", "Models", "Services", "ViewModels", "Views"]
        )
    ]
)
