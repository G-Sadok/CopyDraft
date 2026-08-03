// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CopyDraft",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CopyDraft", targets: ["CopyDraft"])
    ],
    dependencies: [
        // Persistance SQLite : requêtes typées, migrations explicites, observation (ADR-1).
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "CopyDraftCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
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
