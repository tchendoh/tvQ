import SwiftUI

/// Titre d'un réglage avec une phrase grise en dessous, comme dans les Réglages d'iOS.
struct SettingLabel: View {
    let title: Text
    let detail: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            detail
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Ligne de la page d'accueil de Settings : icône dans un carré de couleur,
/// titre, et valeur actuelle à droite (on voit l'état sans ouvrir la page).
struct SettingsRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color
    var value: Text?
    var valueColor: Color = .secondary

    var body: some View {
        LabeledContent {
            if let value {
                value.foregroundStyle(valueColor)
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                SettingsIcon(systemImage: systemImage, color: color)
            }
        }
    }
}

struct SettingsIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Pastille d'initiales pour la carte de compte.
struct AccountAvatar: View {
    enum Style {
        /// Disque rose plein, initiales en blanc (carte de compte).
        case filled
        /// Sans disque : initiales ou silhouette en rose, posées sur le verre de
        /// la barre d'outils. Le rose plein y faisait concurrence au bouton de
        /// suivi de la fiche, seule action à mériter la couleur (2026-10-22).
        /// Essayé et écarté : le verre Clear teinté du bouton de suivi, peu
        /// lisible sur les fonds clairs de la barre.
        case glyph
    }

    let user: AppUser?
    var size: CGFloat = 56
    var style: Style = .filled

    private var initials: String {
        guard let user, !user.isAnonymous else { return "" }
        let source = user.displayName ?? user.email
        let parts = source
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." })
            .prefix(2)
        return parts.compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    var body: some View {
        let foreground: Color = style == .filled ? .white : .accentColor
        ZStack {
            if style == .filled {
                Circle().fill(Color.accentColor.gradient)
            }
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(foreground)
            } else {
                Text(verbatim: initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(foreground)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
