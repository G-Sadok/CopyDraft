import Foundation

/// Identité de l'application, partagée par toutes les couches.
///
/// Les valeurs sont dupliquées dans `Scripts/Info.plist` : `AppInfoTests` vérifie
/// que les deux sources restent cohérentes.
public enum AppInfo {
    public static let name = "CopyDraft"
    public static let bundleIdentifier = "com.copydraft.CopyDraft"
    public static let minimumSystemVersion = "14.0"

    /// Version marketing, lue depuis le bundle quand l'exécutable tourne dans `CopyDraft.app`.
    public static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Numéro de build, lu depuis le bundle.
    public static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
