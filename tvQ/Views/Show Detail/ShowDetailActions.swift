import SwiftUI

/// Rangée d'actions de l'en-tête de la fiche, sous le titre : un grand bouton
/// « Follow » / « Following » et, une fois la série suivie, la cloche à côté.
/// Modèle du bouton « Play » de l'app TV d'Apple : l'action principale de la
/// fiche, pleine largeur, plutôt qu'une pastille dans un coin de l'image.
/// Disposition choisie le 2026-10-22 ; apparence du bouton : verre Clear teinté
/// de rose (FollowWideButton.Look.clearTinted, Style Lab variante E).
///
/// Posée sur l'image : mode sombre forcé, comme les pastilles (ToggleBadgeLabel),
/// pour que le verre reste lisible peu importe l'image.
struct ShowDetailActions: View {
    let showID: String

    @Environment(FollowedShowsStore.self) private var followedShowsStore

    /// Largeur maximale de la rangée (bouton + cloche), environ celle d'un
    /// iPhone en portrait.
    static let maxWidth: CGFloat = 400

    var body: some View {
        let isFollowing = followedShowsStore.isFollowing(showID)
        HStack(spacing: 10) {
            FollowWideButton(isFollowing: isFollowing) {
                withAnimation(.spring) { followedShowsStore.toggle(showID: showID) }
            }
            NotificationBell(showID: showID, style: .glass)
                .transition(.scale.combined(with: .opacity))
        }
        // Pleine largeur sur un iPhone en portrait, mais plafonnée ailleurs
        // (paysage, iPhone Duo, iPad) : au-delà, un bouton aussi long se lit
        // comme une barre plutôt que comme un bouton. L'app TV fait de même.
        .frame(maxWidth: Self.maxWidth, alignment: .leading)
        .animation(.spring, value: isFollowing)
        .environment(\.colorScheme, .dark)
    }
}

/// Bouton de suivi pleine largeur. Une fois la série suivie : verre neutre,
/// « Following » en blanc. Pas suivie : l'invitation, dont l'apparence se
/// compare dans Debug › Style Lab (`Look`). Même grammaire de couleur que
/// FollowIcon : le rose marque l'action à poser.
struct FollowWideButton: View {
    /// Apparence de l'état « pas suivie ».
    enum Look: String, CaseIterable, Identifiable {
        /// Verre proéminent rose plein (première version, 2026-10-22).
        case solid
        /// Verre neutre, contour et texte roses.
        case outlined
        /// Verre teinté de rose, texte blanc.
        case tinted
        /// Verre neutre, seul le « + » est rose.
        case accentIcon
        /// Variante Clear du verre, légèrement teintée de rose : celle qu'Apple
        /// recommande sur une image vive, avec une couche assombrissante dessous
        /// (ici, le dégradé de l'en-tête). WWDC25, « Meet Liquid Glass ».
        case clearTinted

        var id: Self { self }
    }

    /// Apparence retenue pour l'app.
    static let defaultLook: Look = .clearTinted

    let isFollowing: Bool
    var look: Look = FollowWideButton.defaultLook
    let action: () -> Void

    var body: some View {
        Group {
            if !isFollowing && look == .solid {
                Button(action: action) { label }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                    .controlSize(.large)
            } else {
                Button(action: action) {
                    label
                        .padding(.vertical, 14)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(glass, in: Capsule())
                .overlay {
                    if !isFollowing && look == .outlined {
                        Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }

    private var glass: Glass {
        if !isFollowing && look == .tinted {
            .regular.tint(Color.accentColor.opacity(0.45)).interactive()
        } else if !isFollowing && look == .clearTinted {
            .clear.tint(Color.accentColor.opacity(0.3)).interactive()
        } else {
            .regular.interactive()
        }
    }

    private var textColor: Color {
        guard !isFollowing else { return .white }
        return look == .outlined ? .accentColor : .white
    }

    private var label: some View {
        Label {
            Text(isFollowing ? "Following" : "Follow")
                .contentTransition(.interpolate)
                .foregroundStyle(textColor)
        } icon: {
            Image(systemName: isFollowing ? "checkmark" : "plus")
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                .symbolEffect(.bounce, value: isFollowing)
                .foregroundStyle(!isFollowing && look == .accentIcon ? .accentColor : textColor)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
}
