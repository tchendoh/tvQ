import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity d'un soir de diffusion, en une rangée compacte : vignette de la série,
/// titre de la série, état en gros à droite, barre de progression en bas.
///
/// Aucune mise à jour pendant l'épisode : `Text(_:style: .timer)` compte à rebours
/// jusqu'au début puis compte le temps écoulé, la barre se remplit seule pendant
/// l'épisode, et `isStale` (staleDate = fin) fait passer à « Terminé ».
struct EpisodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EpisodeActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(context.attributes.tintColor)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(TvQLink.show(tmdbID: context.attributes.tmdbID))
        } dynamicIsland: { context in
            let attributes = context.attributes
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Artwork(attributes: attributes)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusTimer(context: context)
                        .font(.title3.bold().monospacedDigit())
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attributes.showTitle)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EpisodeProgress(context: context)
                }
            } compactLeading: {
                // Île réduite : à gauche, la série en sigle rose (comme MTL ou TOR dans
                // les apps de sport) ; à droite, l'état. Le rose signe l'app. Un sigle
                // plutôt que l'image : lisible en tout petit, et la barre des menus du
                // Mac affichait la vignette en pavé gris.
                if attributes.showInitials.isEmpty {
                    TvQLogo()
                        .frame(height: 12)
                } else {
                    Text(verbatim: attributes.showInitials)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(tvQMagenta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(Text(verbatim: attributes.showTitle))
                }
            } compactTrailing: {
                CompactTrailing(context: context)
            } minimal: {
                // Pastille ronde : le sigle de la série au centre de l'anneau rose.
                ZStack {
                    ProgressView(timerInterval: attributes.airDate...attributes.endDate, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(tvQMagenta)

                    if attributes.showInitials.isEmpty {
                        Image(systemName: "tv.fill")
                            .font(.caption2)
                            .foregroundStyle(tvQMagenta)
                    } else {
                        Text(verbatim: attributes.showInitials)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(tvQMagenta)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 3)
                    }
                }
            }
            .widgetURL(TvQLink.show(tmdbID: attributes.tmdbID))
            .keylineTint(tvQMagenta)
        }
    }
}

// MARK: - Écran verrouillé

private struct LockScreenView: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>
    private var attributes: EpisodeActivityAttributes { context.attributes }

    var body: some View {
        // Version compacte, une seule rangée : vignette de la série, textes, et à
        // droite un anneau qui se remplit pendant l'épisode, avec le temps au centre.
        // Fond aux couleurs de la série (déjà assombri pour du texte blanc), accent
        // pour l'anneau et le temps.
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Artwork(attributes: attributes)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    // Signature de l'app (iOS n'affiche pas son icône sur l'écran
                    // verrouillé), puis le diffuseur dans sa casse d'origine.
                    HStack(spacing: 6) {
                        TvQLogo()
                            .frame(height: 10)
                        // Diffuseur et numéro d'épisode, discrets : « Disney+ · S01E01 ».
                        Text(verbatim: [attributes.network, attributes.episodeCode]
                            .compactMap { $0 }
                            .joined(separator: " · "))
                            .font(.caption2.weight(.semibold))
                            .opacity(0.75)
                            .lineLimit(1)
                    }
                    // Seulement la série : on veut savoir qu'elle joue, pas quel épisode.
                    // Rapetisse un peu avant d'être coupé (« Arrested Development »).
                    Text(attributes.showTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(attributes.airDate, style: .time) – \(attributes.endDate, style: .time)")
                        .font(.caption2)
                        .opacity(0.7)
                        .lineLimit(1)
                }
                // Le titre passe avant l'état quand la place manque.
                .layoutPriority(1)

                Spacer(minLength: 8)

                StatusRing(context: context)
                    .frame(width: 54, height: 54)
            }
        }
        .padding(14)
        .background(attributes.tintColor)
        .foregroundStyle(.white)
    }
}

// MARK: - Éléments communs

/// Anneau d'état : vide avant le début, il se remplit seul pendant l'épisode
/// (ProgressView à intervalle de dates, aucune mise à jour nécessaire). Au centre,
/// le style `.timer` compte à rebours jusqu'au début, puis compte le temps écoulé :
/// l'anneau et le chiffre avancent ensemble. Coche à la fin.
private struct StatusRing: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>

    var body: some View {
        let attributes = context.attributes
        ZStack {
            ProgressView(timerInterval: attributes.airDate...attributes.endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(attributes.accent)

            if context.isStale {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(attributes.accent)
                    .accessibilityLabel(Text("Ended"))
            } else {
                Text(attributes.airDate, style: .timer)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(attributes.accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// Compte à rebours jusqu'au début, puis temps écoulé ; « Terminé » à la fin.
private struct StatusTimer: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>

    var body: some View {
        if context.isStale {
            Text("Ended")
        } else {
            Text(context.attributes.airDate, style: .timer)
        }
    }
}

/// Se remplit seule entre le début et la fin de l'épisode (vide avant).
private struct EpisodeProgress: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>

    var body: some View {
        let attributes = context.attributes
        ProgressView(timerInterval: attributes.airDate...attributes.endDate, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(attributes.accent)
    }
}

/// Dynamic Island compacte. Plus étroite en paysage et sur l'iPhone Duo (île
/// verticale) : la barre circulaire seule plutôt que le compte à rebours.
/// isDynamicIslandLimitedInWidth n'existe que depuis iOS 27 : avant, la largeur
/// est considérée comme normale.
private struct CompactTrailing: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedWidthReader { isLimitedInWidth in
                CompactTrailingContent(context: context, isLimitedInWidth: isLimitedInWidth)
            }
        } else {
            CompactTrailingContent(context: context, isLimitedInWidth: false)
        }
    }
}

/// Lit isDynamicIslandLimitedInWidth (iOS 27) : un @Environment ne peut pas être
/// conditionnel, d'où cette petite vue réservée à iOS 27.
@available(iOS 27.0, *)
private struct LimitedWidthReader<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        content(isLimitedInWidth)
    }
}

private struct CompactTrailingContent: View {
    let context: ActivityViewContext<EpisodeActivityAttributes>
    let isLimitedInWidth: Bool

    var body: some View {
        let attributes = context.attributes
        if isLimitedInWidth || context.isStale {
            ProgressView(timerInterval: attributes.airDate...attributes.endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(tvQMagenta)
        } else {
            Text(attributes.airDate, style: .timer)
                .monospacedDigit()
                .foregroundStyle(tvQMagenta)
                .frame(maxWidth: 52)
        }
    }
}

/// Image de fond de la série (fichier de l'App Group), sinon sa couleur.
private struct Artwork: View {
    let attributes: EpisodeActivityAttributes

    var body: some View {
        if let image = attributes.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            attributes.tintColor
        }
    }
}

// MARK: - Couleurs et image

/// Logo de tvQ, tiré directement de l'export Icon Composer (tvQlogo-iOS-Default).
private struct TvQLogo: View {
    var body: some View {
        Image("tvQLogo")
            .resizable()
            .scaledToFit()
            .accessibilityLabel(Text(verbatim: "tvQ"))
    }
}

/// Magenta de tvQ : repli quand la série n'a pas d'image.
/// Même valeur que le « Q » du logo (232, 61, 158).
private let tvQMagenta = Color(red: 232 / 255, green: 61 / 255, blue: 158 / 255)

private extension EpisodeActivityAttributes {
    /// Couleur du bandeau (sombre, pour du texte blanc).
    var tintColor: Color {
        tint?.color ?? tvQMagenta.opacity(0.85)
    }

    /// Couleur d'accent sur fond noir (compte à rebours, barre) : calcul commun
    /// avec la fiche (ShowColor.resolvedAccent), sinon le magenta de tvQ.
    var accent: Color {
        ShowColor.resolvedAccent(accent: accentTint, dominant: tint)?.color ?? tvQMagenta
    }

    var image: UIImage? {
        guard let imageFileName, let directory = AppGroup.activityImagesURL else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(imageFileName).path)
    }
}

// MARK: - Aperçus

extension EpisodeActivityAttributes {
    fileprivate static var preview: EpisodeActivityAttributes {
        let air = Date.now + 10 * 60
        return EpisodeActivityAttributes(
            episodeID: "95396-s2e4",
            tmdbID: 95396,
            showTitle: "Severance",
            network: "Apple TV+",
            episodeCode: "S02E04",
            episodeTitle: "Woe's Hollow",
            airDate: air,
            endDate: air + 50 * 60,
            imageFileName: nil,
            tint: ShowColor(red: 0.05, green: 0.18, blue: 0.32),
            accentTint: ShowColor(red: 1.0, green: 0.62, blue: 0.25)
        )
    }
}

#Preview("Écran verrouillé", as: .content, using: EpisodeActivityAttributes.preview) {
    EpisodeLiveActivity()
} contentStates: {
    EpisodeActivityAttributes.ContentState()
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: EpisodeActivityAttributes.preview) {
    EpisodeLiveActivity()
} contentStates: {
    EpisodeActivityAttributes.ContentState()
}
