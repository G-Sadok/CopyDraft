import Foundation

/// Chaîne complète de la capture : surveiller → filtrer → classer → enregistrer.
///
/// C'est le seul endroit où les composants de l'epic E1 se rencontrent. Chacun reste pur et
/// testable de son côté ; le coordinateur ne fait que les mettre bout à bout, dans l'ordre
/// exigé par la confidentialité — le filtre passe **avant** toute lecture de contenu (FR-9).
@MainActor
public final class CaptureCoordinator {
    private let monitor: ClipboardMonitor
    private let gate: PrivacyGate
    private let classifier: ContentClassifier
    private let previewBuilder: PreviewBuilder
    private let store: HistoryStore
    private let preferences: Preferences
    private let cipher: Cipher
    private let now: @Sendable () -> Date

    /// Dernière décision de refus, pour le diagnostic (aucune trace n'est journalisée).
    public private(set) var lastRejection: PrivacyDecision?

    public init(
        monitor: ClipboardMonitor,
        store: HistoryStore,
        preferences: Preferences,
        cipher: Cipher,
        gate: PrivacyGate = PrivacyGate(),
        classifier: ContentClassifier = ContentClassifier(),
        previewBuilder: PreviewBuilder = PreviewBuilder(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.monitor = monitor
        self.store = store
        self.preferences = preferences
        self.cipher = cipher
        self.gate = gate
        self.classifier = classifier
        self.previewBuilder = previewBuilder
        self.now = now
    }

    /// Branche le filtre et l'enregistrement, puis démarre la surveillance.
    public func start() {
        monitor.shouldCapture = { [weak self] types, source in
            guard let self else { return false }
            let decision = self.gate.decide(
                availableTypes: types,
                sourceBundleIdentifier: source.bundleIdentifier,
                captureEnabled: self.preferences.captureEnabled,
                excludedBundleIdentifiers: self.preferences.excludedBundleIdentifiers
            )
            self.lastRejection = decision == .allow ? nil : decision
            return decision == .allow
        }

        monitor.onCapture = { [weak self] content, source in
            guard let self else { return }
            Task { @MainActor in await self.record(content, from: source) }
        }

        monitor.start()
    }

    public func stop() {
        monitor.stop()
        monitor.shouldCapture = nil
        monitor.onCapture = nil
    }

    // MARK: Enregistrement

    /// Transforme un contenu brut en élément d'historique et le confie au magasin.
    func record(_ content: CapturedContent, from source: SourceApp) async {
        let subtype = classifier.classify(content)
        let item = ClipItem(
            kind: content.kind,
            subtype: subtype,
            createdAt: now(),
            source: source,
            byteCount: content.byteCount,
            pixelSize: content.pixelSize,
            characterCount: content.characterCount,
            searchText: previewBuilder.searchText(for: content),
            previewLines: previewBuilder.previewLines(for: content, subtype: subtype)
        )

        await store.ingest(
            item: item,
            content: StoredContent(
                text: content.text,
                rtfData: content.rtfData,
                htmlData: content.htmlData
            ),
            // L'empreinte est un HMAC : deux contenus identiques se reconnaissent, sans que
            // l'empreinte elle-même dise quoi que ce soit du contenu (FR-6).
            contentHash: cipher.contentHash(content.fingerprintData),
            imageData: content.imageData
        )
    }
}
