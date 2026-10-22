import SwiftUI

#if DEBUG
/// Debug › Style Lab : comparaison côte à côte des styles possibles pour les deux
/// interrupteurs d'une série (suivi et cloche) : en-tête de la fiche, sur une
/// image et dans une liste.
/// État local seulement : rien n'est écrit dans FollowedShowsStore. Textes non
/// traduits (debug).
struct StyleLabView: View {
    @State private var isFollowed = true
    @State private var alertsOn = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $isFollowed) { Text(verbatim: "Followed") }
                Toggle(isOn: $alertsOn) { Text(verbatim: "Episode alerts on") }
            } footer: {
                Text(verbatim: "The icons below can be tapped too. Each sample is shown on a dark and a bright image to check legibility.")
            }

            ForEach(FollowWideButton.Look.allCases) { look in
                Section {
                    followLookSample(look, background: .dark)
                    followLookSample(look, background: .bright)
                } header: {
                    Text(verbatim: "Follow button · \(Self.title(of: look))")
                } footer: {
                    Text(verbatim: Self.note(of: look))
                }
                .listRowInsets(EdgeInsets())
            }

            ForEach(BadgeVariant.allCases) { variant in
                Section {
                    posterSample(variant, background: .dark)
                    posterSample(variant, background: .bright)
                } header: {
                    Text(verbatim: "On an image · \(variant.title)")
                } footer: {
                    Text(verbatim: variant.note)
                }
                .listRowInsets(EdgeInsets())
            }

            ForEach(ListVariant.allCases) { variant in
                Section {
                    listSample(variant)
                } header: {
                    Text(verbatim: "In a list · \(variant.title)")
                } footer: {
                    Text(verbatim: variant.note)
                }
            }
        }
        .navigationTitle(Text(verbatim: "Style Lab"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Échantillons

    private enum SampleBackground {
        case dark, bright

        var gradient: LinearGradient {
            switch self {
            case .dark:
                LinearGradient(colors: [Color(red: 0.35, green: 0.12, blue: 0.08), Color(red: 0.12, green: 0.06, blue: 0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            case .bright:
                LinearGradient(colors: [Color(red: 0.98, green: 0.86, blue: 0.45), Color(red: 0.95, green: 0.95, blue: 0.92)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func posterSample(_ variant: BadgeVariant, background: SampleBackground) -> some View {
        HStack(alignment: .bottom) {
            Text(verbatim: "VisionQuest")
                .font(.title.bold())
                .foregroundStyle(.white)
                .shadow(radius: 4)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                badge(.alerts, variant: variant)
                badge(.follow, variant: variant)
            }
        }
        .padding()
        .frame(height: 110, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .background(background.gradient)
    }

    private func listSample(_ variant: ListVariant) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(SampleBackground.dark.gradient)
                .frame(width: 40, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "VisionQuest").font(.headline)
                Text(verbatim: "S01E05 · Today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            listIcon(.alerts, variant: variant)
            listIcon(.follow, variant: variant)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Interrupteurs

    private enum Kind { case follow, alerts }

    private func isOn(_ kind: Kind) -> Bool {
        kind == .follow ? isFollowed : alertsOn
    }

    private func toggle(_ kind: Kind) {
        withAnimation(.spring) {
            if kind == .follow { isFollowed.toggle() } else { alertsOn.toggle() }
        }
    }

    /// Couleur commune proposée : rose = action à poser (pas suivie), emphasis =
    /// actif, tertiary = alertes coupées.
    private func unifiedColor(_ kind: Kind) -> Color {
        switch (kind, isOn(kind)) {
        case (.follow, false): .accentColor
        case (.alerts, false): Color.secondary.opacity(0.6)
        default: .emphasis
        }
    }

    private func symbol(_ kind: Kind, circled: Bool) -> String {
        let base = switch (kind, isOn(kind)) {
        case (.follow, true): "checkmark"
        case (.follow, false): "plus"
        case (.alerts, true): "bell"
        case (.alerts, false): "bell.slash"
        }
        return circled ? base + ".circle" : base
    }

    private func animatedSymbol(_ name: String, kind: Kind) -> some View {
        Image(systemName: name)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
            .symbolEffect(.bounce, value: isOn(kind))
    }

    // MARK: Sur une image

    private enum BadgeVariant: String, CaseIterable, Identifiable {
        case current, unified, filledWhenOn, systemGlass
        var id: Self { self }

        var title: String {
            switch self {
            case .current: "A. Current"
            case .unified: "B. Unified glass"
            case .filledWhenOn: "C. Filled when on"
            case .systemGlass: "D. System glass buttons"
            }
        }

        var note: String {
            switch self {
            case .current: "checkmark.circle / plus.viewfinder in .headline; bell in .callout, gray. Circle inside a circle on one side only."
            case .unified: "Same badge, font and color rule for both. Glyphs without a circle: the badge provides it."
            case .filledWhenOn: "Like B, but the active state fills the badge (dark glyph on a light disc). The state reads at a glance, at the cost of more weight."
            case .systemGlass: "Native .glass / .glassProminent buttons (iOS 26). Not followed uses the prominent pink style as an invitation."
            }
        }
    }

    @ViewBuilder
    private func badge(_ kind: Kind, variant: BadgeVariant) -> some View {
        switch variant {
        case .current:
            Button { toggle(kind) } label: {
                Group {
                    if kind == .follow {
                        Image(systemName: isFollowed ? "checkmark.circle" : "plus.viewfinder")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(isFollowed ? Color.emphasis : .accentColor)
                    } else {
                        Image(systemName: alertsOn ? "bell" : "bell.slash")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(alertsOn ? .secondary : .tertiary)
                    }
                }
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(
                        (kind == .follow && !isFollowed ? Color.accentColor : Color.emphasis).opacity(0.5),
                        lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .glassBadgeEnvironment()

        case .unified:
            Button { toggle(kind) } label: {
                animatedSymbol(symbol(kind, circled: false), kind: kind)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(unifiedColor(kind))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().strokeBorder(unifiedColor(kind).opacity(0.5), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .glassBadgeEnvironment()

        case .filledWhenOn:
            Button { toggle(kind) } label: {
                animatedSymbol(symbol(kind, circled: false), kind: kind)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isOn(kind) ? Color.black : unifiedColor(kind))
                    .frame(width: 34, height: 34)
                    .background {
                        if isOn(kind) {
                            Circle().fill(Color.emphasis)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay { Circle().strokeBorder(unifiedColor(kind).opacity(0.5), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .glassBadgeEnvironment()

        case .systemGlass:
            let label = animatedSymbol(symbol(kind, circled: false), kind: kind)
                .font(.headline.weight(.bold))
                .frame(width: 22, height: 22)
            if kind == .follow && !isFollowed {
                Button { toggle(kind) } label: { label }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor)
            } else {
                Button { toggle(kind) } label: {
                    label.foregroundStyle(unifiedColor(kind))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .environment(\.colorScheme, .dark)
            }
        }
    }

    // MARK: Bouton de suivi de la fiche

    private static func title(of look: FollowWideButton.Look) -> String {
        let name = switch look {
        case .solid: "A. Solid pink"
        case .outlined: "B. Glass, pink outline"
        case .tinted: "C. Pink-tinted glass"
        case .accentIcon: "D. Glass, pink plus only"
        case .clearTinted: "E. Clear glass, light pink tint"
        }
        return look == FollowWideButton.defaultLook ? name + " (in use)" : name
    }

    private static func note(of look: FollowWideButton.Look) -> String {
        switch look {
        case .solid: "Prominent glass, solid pink. Hard to miss, but loud on most images."
        case .outlined: "Neutral glass with a pink outline and pink text. Pink text can be hard to read on busy or warm images."
        case .tinted: "Glass lightly tinted pink, white text. Still reads as the invitation, while the image shows through."
        case .accentIcon: "Neutral glass; only the plus is pink. The quietest: close to the Following state."
        case .clearTinted: "Apple's Clear glass, meant for controls over bright media with a dimming layer underneath (the header gradient). Lightly tinted pink."
        }
    }

    /// Titre, bouton de suivi et cloche, comme l'en-tête de la fiche.
    private func followLookSample(_ look: FollowWideButton.Look, background: SampleBackground) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "VisionQuest")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .shadow(radius: 4)
            HStack(spacing: 10) {
                FollowWideButton(isFollowing: isFollowed, look: look) { toggle(.follow) }
                sampleBell
            }
            .environment(\.colorScheme, .dark)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .bottomLeading)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: UnitPoint(x: 0.5, y: 0.35), endPoint: .bottom)
                .background(background.gradient)
        }
    }

    @ViewBuilder
    private var sampleBell: some View {
        if isFollowed {
            Button { toggle(.alerts) } label: {
                Image(systemName: alertsOn ? "bell" : "bell.slash")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.headline)
                    .foregroundStyle(alertsOn ? .primary : .secondary)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Dans une liste

    private enum ListVariant: String, CaseIterable, Identifiable {
        case current, circled, plain
        var id: Self { self }

        var title: String {
            switch self {
            case .current: "A. Current"
            case .circled: "B. Circled pair"
            case .plain: "C. Plain pair"
            }
        }

        var note: String {
            switch self {
            case .current: "My Shows: checkmark.circle in .title3, emphasis. Schedule: bell alone, gray. (Never side by side today.)"
            case .circled: "Both with a circle, same size, .secondary when on: a visible target in a row without a badge."
            case .plain: "Both without a circle, same size: lighter, closer to the badges."
            }
        }
    }

    @ViewBuilder
    private func listIcon(_ kind: Kind, variant: ListVariant) -> some View {
        Button { toggle(kind) } label: {
            switch variant {
            case .current:
                if kind == .follow {
                    Image(systemName: isFollowed ? "checkmark.circle" : "plus.viewfinder")
                        .font(.title3)
                        .foregroundStyle(isFollowed ? Color.emphasis : .accentColor)
                } else {
                    Image(systemName: alertsOn ? "bell" : "bell.slash")
                        .foregroundStyle(alertsOn ? .secondary : .tertiary)
                }
            case .circled, .plain:
                animatedSymbol(symbol(kind, circled: variant == .circled), kind: kind)
                    .font(.title3)
                    .foregroundStyle(listColor(kind))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private func listColor(_ kind: Kind) -> Color {
        switch (kind, isOn(kind)) {
        case (.follow, false): .accentColor
        case (.alerts, false): Color.secondary.opacity(0.6)
        default: .secondary
        }
    }
}

private extension View {
    /// Comme FollowBadge : mode sombre forcé et ombre, lisible sur toute image.
    func glassBadgeEnvironment() -> some View {
        environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    NavigationStack {
        StyleLabView()
    }
}
#endif
