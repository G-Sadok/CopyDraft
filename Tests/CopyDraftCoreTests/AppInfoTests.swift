import Foundation
import Testing

@testable import CopyDraftCore

@Suite("Identité de l'application")
struct AppInfoTests {
    /// `Scripts/Info.plist` et `AppInfo` décrivent la même application : toute
    /// divergence casserait l'identité utilisée par TCC (permission Accessibilité).
    @Test("AppInfo et Info.plist restent cohérents")
    func infoPlistMatchesAppInfo() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CopyDraftCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // racine du dépôt
            .appendingPathComponent("Scripts/Info.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(plist["CFBundleIdentifier"] as? String == AppInfo.bundleIdentifier)
        #expect(plist["CFBundleName"] as? String == AppInfo.name)
        #expect(plist["CFBundleExecutable"] as? String == AppInfo.name)
        #expect(plist["LSMinimumSystemVersion"] as? String == AppInfo.minimumSystemVersion)
    }

    /// L'application est un agent : ni Dock, ni fenêtre au lancement.
    @Test("L'application est déclarée en agent (LSUIElement)")
    func appIsAnAgent() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Scripts/Info.plist")

        let data = try Data(contentsOf: plistURL)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(plist["LSUIElement"] as? Bool == true)
    }
}
