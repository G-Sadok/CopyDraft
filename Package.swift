// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CopyDraft",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CopyDraft", targets: ["CopyDraft"])
    ],
    dependencies: [],
    targets: [
        .target(name: "CopyDraftCore"),
        .target(
            name: "CopyDraftUI",
            dependencies: ["CopyDraftCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "CopyDraft", dependencies: ["CopyDraftCore", "CopyDraftUI"]),
        .testTarget(name: "CopyDraftCoreTests", dependencies: ["CopyDraftCore"]),
        .testTarget(name: "CopyDraftUITests", dependencies: ["CopyDraftUI"])
    ],
    swiftLanguageModes: [.v6]
)
