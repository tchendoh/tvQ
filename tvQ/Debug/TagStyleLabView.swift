import SwiftUI

// MARK: - TEMPORAIRE
//
// Page de test pour explorer différents looks de tag (numéro d'épisode /
// "Premiere") et d'icône de suivi (FollowIcon) avant d'arrêter un style
// définitif. À supprimer une fois les styles choisis — voir aussi le point
// d'accès temporaire dans SettingsView (section "Developer").
//
// Chaque style est montré sur un fond clair ET un fond sombre — certains
// looks (le néon en particulier) ne se jugent pas pareil sur les deux fonds.

/// Un look à l'essai, partagé entre les tags et FollowIcon — permet d'itérer
/// sans dupliquer le harnais d'affichage (StyleSwatch) pour chaque nouvelle
/// idée, et garde les deux exercices visuellement comparables.
private enum LabLookStyle: String, CaseIterable, Identifiable {
    case minimalist = "Minimalist (actuel)"
    case neon = "Neon"
    case glossy = "Glossy"
    case metallic = "Metallic"
    case metallicTinted = "Metallic (Tinted)"
    case glass = "Glass (iOS 26)"

    var id: String { rawValue }
}

/// Dégradés réutilisés tels quels par les nouveaux composants du lab
/// (provider badge, card, placeholder, bouton) — évite de retaper les mêmes
/// stops à chaque nouveau composant. LabTag/LabFollowIcon gardent leurs
/// définitions inline (ajoutées avant celles-ci) plutôt que d'être migrés,
/// pour ne pas risquer de régresser un style déjà validé.
private enum LabGradients {
    static let metallicGray = LinearGradient(
        stops: [
            .init(color: Color(white: 0.85), location: 0),
            .init(color: Color(white: 0.65), location: 0.35),
            .init(color: Color(white: 0.92), location: 0.55),
            .init(color: Color(white: 0.6), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let metallicTintOverlay = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.55), location: 0),
            .init(color: .white.opacity(0.05), location: 0.35),
            .init(color: .black.opacity(0.25), location: 0.55),
            .init(color: .white.opacity(0.2), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func glossyFill(_ tint: Color) -> LinearGradient {
        LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.65)], startPoint: .top, endPoint: .bottom)
    }

    static let glossyReflection = LinearGradient(
        colors: [.white.opacity(0.5), .white.opacity(0)],
        startPoint: .top,
        endPoint: .center
    )
}

struct TagStyleLabView: View {
    private let episodeText = "S04E01"
    private let premiereText = "PREMIERE"

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                section(title: "Episode Tags") { style in
                    HStack(spacing: 8) {
                        LabTag(text: episodeText, kind: .episode, look: style)
                        LabTag(text: premiereText, kind: .premiere, look: style)
                    }
                }

                Divider()

                section(title: "Follow Icon") { style in
                    HStack(spacing: 16) {
                        LabFollowIcon(isFollowing: false, look: style)
                        LabFollowIcon(isFollowing: true, look: style)
                    }
                }

                Divider()

                // Actuellement du texte seul dans ShowDetailView (voir
                // BACKLOG.md, "Où regarder par pays") — aucun traitement
                // visuel arrêté, donc bon candidat pour le même exercice.
                section(title: "Watch Provider Badge") { style in
                    HStack(spacing: 8) {
                        LabProviderBadge(text: "Netflix", look: style)
                        LabProviderBadge(text: "Apple TV+", look: style)
                    }
                }

                Divider()

                // Le conteneur qui donne le ton général de l'app (utilisé
                // pour chaque jour dans Schedule) — un changement ici a plus
                // d'impact visuel que sur un petit tag.
                section(title: "Grouped Card") { style in
                    LabCard(look: style)
                }

                Divider()

                // Le placeholder d'affiche pendant le chargement
                // (RetryingAsyncImage) et les états vides (ContentUnavailableView).
                section(title: "Placeholder / Empty State") { style in
                    LabPlaceholder(look: style)
                }

                Divider()

                // L'app n'a pas encore de vrai bouton primaire (Follow est un
                // badge, Sign in with Apple impose son propre style) — utile
                // à fixer avant d'en avoir besoin pour de vrai (ex. un futur
                // CTA d'abonnement, voir BACKLOG.md).
                section(title: "Primary Button") { style in
                    LabPrimaryButton(text: "Continue", look: style)
                }
            }
            .padding()
        }
        .navigationTitle("Style Lab")
    }

    /// Une section = un titre de groupe ("Episode Tags", "Follow Icon") suivi
    /// d'une rangée claire/sombre par style — factorisé pour que les deux
    /// exercices restent identiques dans leur présentation.
    @ViewBuilder
    private func section<Sample: View>(
        title: String,
        @ViewBuilder sample: @escaping (LabLookStyle) -> Sample
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3.weight(.bold))

            ForEach(LabLookStyle.allCases) { style in
                VStack(alignment: .leading, spacing: 10) {
                    Text(style.rawValue)
                        .font(.headline)

                    HStack(spacing: 12) {
                        StyleSwatch(isDark: false) { sample(style) }
                        StyleSwatch(isDark: true) { sample(style) }
                    }
                }
            }
        }
    }
}

/// Fond clair/sombre côte à côte, indépendant du colorScheme réel de
/// l'appareil — nécessaire pour juger un style sur les deux à la fois sans
/// basculer l'apparence du système.
private struct StyleSwatch<Content: View>: View {
    let isDark: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(isDark ? Color.black : Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .environment(\.colorScheme, isDark ? .dark : .light)
    }
}

/// Un tag, rendu dans l'un des styles à l'essai. Distinct d'EpisodeTag
/// (ScheduleView) exprès : celui-ci n'a pas vocation à survivre, pas la peine
/// de le faire cohabiter avec le code de production.
private struct LabTag: View {
    enum Kind {
        case episode
        case premiere
    }

    let text: String
    let kind: Kind
    let look: LabLookStyle

    /// .emphasis pour un numéro d'épisode, l'accent (rose) pour "Premiere" —
    /// même grammaire de couleur que le tag réel (voir EpisodeTag).
    private var tintColor: Color {
        kind == .episode ? Color.emphasis : .accentColor
    }

    var body: some View {
        switch look {
        case .minimalist:
            Text(text)
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(tintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(tintColor, lineWidth: 1)
                }

        case .neon:
            Text(text)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(tintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tintColor.opacity(0.12))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(tintColor, lineWidth: 1.5)
                }
                // Plusieurs couches de glow superposées (rayons croissants,
                // opacité décroissante) plutôt qu'un seul .shadow — un néon
                // réel diffuse sa lumière sur plusieurs paliers, pas un flou
                // unique.
                .shadow(color: tintColor.opacity(0.9), radius: 2)
                .shadow(color: tintColor.opacity(0.6), radius: 5)
                .shadow(color: tintColor.opacity(0.4), radius: 10)

        case .glossy:
            Text(text)
                .font(.caption2.weight(.bold))
                .tracking(0.4)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(0.95), tintColor.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            // Le "reflet" du haut, typique d'un badge glossy
                            // (ex. anciens boutons web 2.0) : un dégradé blanc
                            // qui s'estompe vers la moitié de la capsule.
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                }
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

        case .metallic:
            Text(text)
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(.black.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                // Alternance claire/foncée façon brossé —
                                // pas juste un dégradé à 2 points, sinon ça
                                // ressemble à du verre plutôt qu'à du métal.
                                stops: [
                                    .init(color: Color(white: 0.85), location: 0),
                                    .init(color: Color(white: 0.65), location: 0.35),
                                    .init(color: Color(white: 0.92), location: 0.55),
                                    .init(color: Color(white: 0.6), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color(white: 0.4), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

        case .metallicTinted:
            // Même structure "brossé" que .metallic (alternance claire/foncée
            // en diagonale), mais les paliers sont mélangés à tintColor
            // plutôt qu'à du gris neutre — l'idée de l'aluminium anodisé
            // (ex. coloris Apple Watch) plutôt que du métal toujours gris.
            Text(text)
                .font(.caption2.weight(.bold))
                .tracking(0.4)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(tintColor)
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.55), location: 0),
                                    .init(color: .white.opacity(0.05), location: 0.35),
                                    .init(color: .black.opacity(0.25), location: 0.55),
                                    .init(color: .white.opacity(0.2), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

        case .glass:
            Text(text)
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(tintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

/// FollowIcon, rendu dans l'un des styles à l'essai. Distinct de FollowIcon
/// (Presentation/Views/FollowIcon.swift) exprès : celui-ci n'a pas vocation à
/// survivre, pas la peine de le faire cohabiter avec le code de production.
///
/// Reprend la même icône/couleur que FollowIcon réel (plus.viewfinder accent
/// si pas suivi, checkmark.circle emphasis si suivi) — seul le traitement
/// visuel autour change d'un style à l'autre.
private struct LabFollowIcon: View {
    let isFollowing: Bool
    let look: LabLookStyle

    private var tintColor: Color {
        isFollowing ? Color.emphasis : .accentColor
    }

    private var symbolName: String {
        isFollowing ? "checkmark.circle" : "plus.viewfinder"
    }

    private var icon: some View {
        Image(systemName: symbolName)
            .font(.system(size: 18, weight: .bold))
    }

    var body: some View {
        switch look {
        case .minimalist:
            // Le FollowIcon réel n'a pas de conteneur du tout — c'est
            // ShowCardView (FollowBadge) qui l'entoure d'un fond noir semi-
            // transparent. Reproduit ici tel quel pour rester une comparaison
            // honnête plutôt qu'une simple icône flottante.
            icon
                .foregroundStyle(tintColor)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))

        case .neon:
            icon
                .foregroundStyle(tintColor)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(tintColor.opacity(0.12))
                }
                .overlay {
                    Circle().strokeBorder(tintColor, lineWidth: 1.5)
                }
                .shadow(color: tintColor.opacity(0.9), radius: 2)
                .shadow(color: tintColor.opacity(0.6), radius: 6)
                .shadow(color: tintColor.opacity(0.4), radius: 12)

        case .glossy:
            icon
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(0.95), tintColor.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.55), .white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

        case .metallic:
            icon
                .foregroundStyle(.black.opacity(0.75))
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(white: 0.85), location: 0),
                                    .init(color: Color(white: 0.65), location: 0.35),
                                    .init(color: Color(white: 0.92), location: 0.55),
                                    .init(color: Color(white: 0.6), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Circle().strokeBorder(Color(white: 0.4), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)

        case .metallicTinted:
            // Même idée que LabTag.metallicTinted : structure brossée
            // (dégradé diagonal clair/foncé) mélangée à tintColor plutôt
            // qu'à du gris — aluminium anodisé plutôt que métal neutre.
            icon
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(tintColor)
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.55), location: 0),
                                    .init(color: .white.opacity(0.05), location: 0.35),
                                    .init(color: .black.opacity(0.25), location: 0.55),
                                    .init(color: .white.opacity(0.2), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)

        case .glass:
            icon
                .foregroundStyle(tintColor)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

/// Badge de diffuseur ("Netflix", "Apple TV+") — actuellement du texte seul
/// dans ShowDetailView (voir BACKLOG.md). Capsule plutôt que le rectangle
/// arrondi des tags : un nom de diffuseur est plus long et variable en
/// longueur qu'un numéro d'épisode, une capsule s'y prête mieux.
private struct LabProviderBadge: View {
    let text: String
    let look: LabLookStyle

    /// Une seule couleur, l'accent — les diffuseurs n'ont pas de couleur de
    /// marque dans l'app aujourd'hui (texte seul), pas la peine d'en
    /// inventer une par service pour cet essai.
    private var tintColor: Color { .accentColor }

    var body: some View {
        switch look {
        case .minimalist:
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay {
                    Capsule().strokeBorder(tintColor, lineWidth: 1)
                }

        case .neon:
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundStyle(tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background { Capsule().fill(tintColor.opacity(0.12)) }
                .overlay { Capsule().strokeBorder(tintColor, lineWidth: 1.5) }
                .shadow(color: tintColor.opacity(0.9), radius: 2)
                .shadow(color: tintColor.opacity(0.6), radius: 5)
                .shadow(color: tintColor.opacity(0.4), radius: 10)

        case .glossy:
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(LabGradients.glossyFill(tintColor))
                        .overlay { Capsule().fill(LabGradients.glossyReflection) }
                }
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

        case .metallic:
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.black.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(LabGradients.metallicGray)
                        .overlay { Capsule().strokeBorder(Color(white: 0.4), lineWidth: 0.5) }
                }
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

        case .metallicTinted:
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(tintColor)
                        .overlay { LabGradients.metallicTintOverlay }
                        .clipShape(Capsule())
                        .overlay { Capsule().strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5) }
                }
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

        case .glass:
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(tintColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(tintColor.opacity(0.5), lineWidth: 1) }
        }
    }
}

/// Version simplifiée de GroupedCard (voir Presentation/Views/GroupedCard.swift)
/// — même idée d'en-tête + contenu délimité, mais avec le style à l'essai
/// appliqué au conteneur plutôt que le traitement fixe actuel. Contenu
/// factice (deux lignes façon "épisode") identique d'un style à l'autre :
/// seul le conteneur doit changer ici.
private struct LabCard: View {
    let look: LabLookStyle

    private var tintColor: Color { .accentColor }
    private var cornerRadius: CGFloat { 16 }

    private var textColor: Color {
        switch look {
        case .glossy, .metallicTinted: .white
        case .metallic: .black.opacity(0.85)
        default: .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("Aug 9")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(textColor.opacity(0.3))

            VStack(alignment: .leading, spacing: 6) {
                Text("Reacher")
                    .font(.subheadline.weight(.semibold))
                Text("S04E01 · S04E02")
                    .font(.caption)
                    .opacity(0.7)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background {
            switch look {
            case .minimalist:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.background.secondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                    }

            case .neon:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor, lineWidth: 1.5)
                    }

            case .glossy:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LabGradients.glossyFill(tintColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(LabGradients.glossyReflection)
                    }

            case .metallic:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LabGradients.metallicGray)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color(white: 0.4), lineWidth: 0.5)
                    }

            case .metallicTinted:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tintColor)
                    .overlay { LabGradients.metallicTintOverlay }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5)
                    }

            case .glass:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(look == .minimalist ? 0 : 0.25), radius: 4, x: 0, y: 2)
    }
}

/// Placeholder d'affiche pendant le chargement (voir RetryingAsyncImage) et
/// états vides (ContentUnavailableView) — actuellement un simple rectangle
/// gris + icône "tv" partout dans l'app, sans traitement particulier.
private struct LabPlaceholder: View {
    let look: LabLookStyle

    private var tintColor: Color { .accentColor }
    private var cornerRadius: CGFloat { 10 }

    private var iconColor: Color {
        switch look {
        case .glossy, .metallicTinted: .white
        case .metallic: .black.opacity(0.6)
        case .minimalist: .secondary
        case .neon, .glass: tintColor
        }
    }

    var body: some View {
        ZStack {
            switch look {
            case .minimalist:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.secondary.opacity(0.15))

            case .neon:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor, lineWidth: 1.5)
                    }
                    .shadow(color: tintColor.opacity(0.7), radius: 4)
                    .shadow(color: tintColor.opacity(0.4), radius: 10)

            case .glossy:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LabGradients.glossyFill(tintColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(LabGradients.glossyReflection)
                    }

            case .metallic:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LabGradients.metallicGray)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color(white: 0.4), lineWidth: 0.5)
                    }

            case .metallicTinted:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tintColor)
                    .overlay { LabGradients.metallicTintOverlay }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5)
                    }

            case .glass:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
                    }
            }

            Image(systemName: "tv")
                .foregroundStyle(iconColor)
        }
        .frame(width: 60, height: 90) // même ratio 2/3 que les vraies affiches
    }
}

/// Bouton primaire — l'app n'en a pas encore de vrai (Follow est un badge,
/// Sign in with Apple a son style imposé) ; utile d'avoir un style prêt pour
/// le jour où un CTA franc sera nécessaire (ex. un abonnement, voir BACKLOG.md).
private struct LabPrimaryButton: View {
    let text: String
    let look: LabLookStyle

    private var tintColor: Color { .accentColor }
    private var cornerRadius: CGFloat { 12 }

    var body: some View {
        switch look {
        case .minimalist:
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(tintColor, lineWidth: 1.5)
                }

        case .neon:
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tintColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tintColor.opacity(0.12))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(tintColor, lineWidth: 1.5)
                }
                .shadow(color: tintColor.opacity(0.9), radius: 2)
                .shadow(color: tintColor.opacity(0.6), radius: 6)
                .shadow(color: tintColor.opacity(0.4), radius: 12)

        case .glossy:
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LabGradients.glossyFill(tintColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(LabGradients.glossyReflection)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

        case .metallic:
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LabGradients.metallicGray)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color(white: 0.4), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        case .metallicTinted:
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tintColor)
                        .overlay { LabGradients.metallicTintOverlay }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(tintColor.opacity(0.6), lineWidth: 0.5)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        case .glass:
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tintColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

#Preview {
    NavigationStack {
        TagStyleLabView()
    }
}
