import SwiftUI

/// En-tête de section de la liste d'historique — « Épinglés », « Récents » (§3).
///
/// Vingt points de haut, capitales, `micro` en `text2` : assez pour séparer deux groupes, pas
/// assez pour se faire remarquer. Le titre est fourni par l'appelant — c'est lui qui sait s'il
/// ouvre la section épinglée ou la section récente, et lui qui détient le catalogue localisé.
///
/// L'en-tête est marqué comme en-tête pour VoiceOver : la navigation par titres saute ainsi
/// d'un groupe à l'autre sans traverser les cellules.
public struct SectionHeader: View {
    private let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.localizedUppercase)
            .font(CD.Font.micro)
            .foregroundStyle(CD.Color.text2)
            .lineLimit(1)
            .frame(
                maxWidth: .infinity,
                minHeight: CD.Metric.popupSectionHeader,
                alignment: .leading
            )
            .padding(.horizontal, CD.Metric.cellPadding)
            .accessibilityAddTraits(.isHeader)
    }
}
