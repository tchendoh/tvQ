import SwiftUI
import UIKit

#if DEBUG
/// Debug › Style Lab : banc d'essai pour comparer des variantes visuelles avant
/// d'en retenir une. L'historique Git garde les anciennes comparaisons.
/// Textes non traduits (debug).
///
/// Comparaison en cours (2026-10-26) : la ligne de métadonnées de la fiche (pastille
/// de statut, genres, pastille de diffuseur) posée sur le reflet de l'image
/// (AmbientReflection), avec de vraies séries. Copie volontaire du rendu de
/// ShowDetailView : on peut tout régler ici sans toucher à la fiche.
struct StyleLabView: View {
    enum LabShow: CaseIterable, Identifiable {
        case slowHorses
        case onlyMurders
        case diplomat
        case severance

        var id: Self { self }
        var label: String {
            switch self {
            case .slowHorses: "Slow Horses"
            case .onlyMurders: "Only Murders"
            case .diplomat: "The Diplomat"
            case .severance: "Severance"
            }
        }
        /// Identifiant TMDB connu ; nil = trouvé par une recherche sur `label`
        /// (premier résultat), faute d'identifiant vérifié.
        var tmdbID: Int? {
            switch self {
            case .slowHorses: 95480
            case .onlyMurders: 107113
            case .diplomat: nil
            case .severance: 95396
            }
        }
    }

    enum PillBackground: String, CaseIterable, Identifiable {
        case color = "Color"
        case material = "Material"
        case glass = "Glass"
        var id: Self { self }
    }

    enum MaterialKind: String, CaseIterable, Identifiable {
        case ultraThin = "Ultra thin", thin = "Thin", regular = "Regular", thick = "Thick", ultraThick = "Ultra thick"
        var id: Self { self }
        var material: Material {
            switch self {
            case .ultraThin: .ultraThinMaterial
            case .thin: .thinMaterial
            case .regular: .regularMaterial
            case .thick: .thickMaterial
            case .ultraThick: .ultraThickMaterial
            }
        }
    }

    enum GlassKind: String, CaseIterable, Identifiable {
        case regular = "Regular", clear = "Clear"
        var id: Self { self }
        var glass: Glass {
            switch self {
            case .regular: .regular
            case .clear: .clear
            }
        }
    }

    /// Couleur d'un texte : un style du système (s'adapte au mode et au réglage
    /// Augmenter le contraste) ou une couleur choisie.
    enum TextStyleChoice: String, CaseIterable, Identifiable {
        case primary = "Primary", secondary = "Secondary", tertiary = "Tertiary", custom = "Custom"
        var id: Self { self }
    }

    /// Fond de la pastille inactive : celui de l'app (fill), ou les mêmes options que l'active.
    enum InactiveBackground: String, CaseIterable, Identifiable {
        case fill = "Fill", color = "Color", material = "Material", glass = "Glass"
        var id: Self { self }
    }

    enum Weight: String, CaseIterable, Identifiable {
        case regular = "Regular", medium = "Medium", semibold = "Semibold", bold = "Bold"
        var id: Self { self }
        var value: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }
    }

    @State private var selectedShow: LabShow = .slowHorses
    @State private var shows: [LabShow: Show] = [:]
    @State private var isDark = false

    /// Un jeu de réglages par mode : l'interrupteur Dark mode passe de l'un à l'autre.
    @State private var lightSettings = LabSettings.currentLight
    @State private var darkSettings = LabSettings.currentDark

    /// Jeu affiché et modifié, selon l'interrupteur.
    private var settings: Binding<LabSettings> {
        isDark ? $darkSettings : $lightSettings
    }

    private let repository = ShowRepository.shared

    private var current: LabSettings { settings.wrappedValue }

    var body: some View {
        Form {
            Section {
                preview
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Picker(selection: $selectedShow) {
                    ForEach(LabShow.allCases) { Text(verbatim: $0.label).tag($0) }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                Toggle(isOn: $isDark) { Text(verbatim: "Dark mode") }
            }

            Section {
                Picker(selection: settings.pillBackground) {
                    ForEach(PillBackground.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                } label: { Text(verbatim: "Background") }
                .pickerStyle(.segmented)
                if current.pillBackground == .material {
                    Picker(selection: settings.materialKind) {
                        ForEach(MaterialKind.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Material") }
                }
                if current.pillBackground == .glass {
                    Picker(selection: settings.glassKind) {
                        ForEach(GlassKind.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Glass") }
                    .pickerStyle(.segmented)
                }
                if current.pillBackground != .material {
                    ColorPicker(selection: settings.pillColor, supportsOpacity: false) {
                        Text(verbatim: current.pillBackground == .glass ? "Glass tint · \(current.pillColor.hex)" : "Background · \(current.pillColor.hex)")
                    }
                    slider(current.pillBackground == .glass ? "Tint opacity" : "Background opacity",
                           value: settings.pillOpacity, in: 0...1, step: 0.01, format: "%.2f")
                }
                ColorPicker(selection: settings.textColor, supportsOpacity: false) {
                    Text(verbatim: "Text · \(current.textColor.hex)")
                }
                Picker(selection: settings.weight) {
                    ForEach(Weight.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                } label: { Text(verbatim: "Weight") }
                Toggle(isOn: settings.hasStroke) { Text(verbatim: "Stroke") }
                if current.hasStroke {
                    slider("Stroke opacity", value: settings.strokeOpacity, in: 0...1, step: 0.01, format: "%.2f")
                }
            } header: {
                Text(verbatim: "Active pill")
            } footer: {
                Text(verbatim: "Applies to the status pill and the included provider pill.")
            }

            Section {
                textStylePicker(style: settings.genresStyle, color: settings.genresColor)
                if current.genresStyle == .custom {
                    slider("Opacity", value: settings.genresOpacity, in: 0...1, step: 0.01, format: "%.2f")
                }
                Picker(selection: settings.genresWeight) {
                    ForEach(Weight.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                } label: { Text(verbatim: "Weight") }
            } header: {
                Text(verbatim: "Genres")
            }

            Section {
                Picker(selection: settings.inactiveBackground) {
                    ForEach(InactiveBackground.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                switch current.inactiveBackground {
                case .fill:
                    EmptyView()
                case .material:
                    Picker(selection: settings.inactiveMaterial) {
                        ForEach(MaterialKind.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { Text(verbatim: "Material") }
                case .color, .glass:
                    if current.inactiveBackground == .glass {
                        Picker(selection: settings.inactiveGlass) {
                            ForEach(GlassKind.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                        } label: { Text(verbatim: "Glass") }
                        .pickerStyle(.segmented)
                    }
                    ColorPicker(selection: settings.inactiveColor, supportsOpacity: false) {
                        Text(verbatim: "\(current.inactiveBackground == .glass ? "Glass tint" : "Background") · \(current.inactiveColor.hex)")
                    }
                    slider(current.inactiveBackground == .glass ? "Tint opacity" : "Background opacity",
                           value: settings.inactiveOpacity, in: 0...1, step: 0.01, format: "%.2f")
                }
                textStylePicker(style: settings.inactiveTextStyle, color: settings.inactiveTextColor)
                Picker(selection: settings.inactiveWeight) {
                    ForEach(Weight.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                } label: { Text(verbatim: "Weight") }
            } header: {
                Text(verbatim: "Inactive pill")
            } footer: {
                Text(verbatim: "Ended status, and providers to rent or buy.")
            }

            Section {
                Button { resetToCurrent() } label: { Text(verbatim: isDark ? "Reset dark mode to app values" : "Reset light mode to app values") }
                Button { UIPasteboard.general.string = settingsSummary } label: {
                    Text(verbatim: "Copy settings")
                }
            } footer: {
                Text(verbatim: "Copy settings puts the values on the clipboard, ready to paste in a conversation.")
            }
        }
        .navigationTitle(Text(verbatim: "Style Lab"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadShows() }
    }

    // MARK: - Aperçu

    private var preview: some View {
        let show = shows[selectedShow]
        return VStack(alignment: .leading, spacing: 0) {
            header(show)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    activePill(statusLabel(show))
                    Text(verbatim: show.map { $0.genres.prefix(3).joined(separator: " · ") } ?? "Drama · Mystery")
                        .font(.subheadline.weight(current.genresWeight.value))
                        .foregroundStyle(textStyle(current.genresStyle, color: current.genresColor, opacity: current.genresOpacity))
                        .lineLimit(1)
                }
                Text(verbatim: show?.overview ?? "Loading…")
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(verbatim: "Included")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    activePill("Apple TV", isProvider: true)
                    inactivePill("Ended")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .top) { reflection(show) }
            .clipped()
        }
        .background(Color(.systemBackground))
        .environment(\.colorScheme, isDark ? .dark : .light)
    }

    private func header(_ show: Show?) -> some View {
        RetryingAsyncImage(url: show?.backdropURL ?? show?.posterURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.secondary.opacity(0.2))
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 160)
        .clipped()
        .overlay {
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: UnitPoint(x: 0.5, y: 0.35), endPoint: .bottom)
        }
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: show?.title ?? selectedShow.label)
                .font(.title.bold())
                .foregroundStyle(.white)
                .padding()
        }
    }

    /// Même construction qu'AmbientReflection, avec les réglages du banc.
    private func reflection(_ show: Show?) -> some View {
        RetryingAsyncImage(url: show?.backdropURL ?? show?.posterURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.clear
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 520)
        .clipped()
        .scaleEffect(y: -1)
        .saturation(current.saturation)
        .blur(radius: current.blur, opaque: true)
        .opacity(current.reflectionOpacity)
        .mask {
            LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func activePill(_ text: String, isProvider: Bool = false) -> some View {
        let label = Text(verbatim: text)
            .font(isProvider ? .caption.weight(current.weight.value) : .caption.weight(current.weight.value))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, isProvider ? 9 : 8)
            .padding(.vertical, isProvider ? 4 : 3)
            .foregroundStyle(current.textColor)
            .overlay {
                if current.hasStroke {
                    Capsule().strokeBorder(current.pillColor.opacity(current.strokeOpacity), lineWidth: 1)
                }
            }

        switch current.pillBackground {
        case .color:
            label.background(current.pillColor.opacity(current.pillOpacity), in: Capsule())
        case .material:
            label.background(current.materialKind.material, in: Capsule())
        case .glass:
            label.glassEffect(current.glassKind.glass.tint(current.pillColor.opacity(current.pillOpacity)), in: Capsule())
        }
    }

    @ViewBuilder
    private func inactivePill(_ text: String) -> some View {
        let label = Text(verbatim: text)
            .font(.caption.weight(current.inactiveWeight.value))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(textStyle(current.inactiveTextStyle, color: current.inactiveTextColor, opacity: 1))

        switch current.inactiveBackground {
        case .fill:
            label.background(.fill.tertiary, in: Capsule())
        case .color:
            label.background(current.inactiveColor.opacity(current.inactiveOpacity), in: Capsule())
        case .material:
            label.background(current.inactiveMaterial.material, in: Capsule())
        case .glass:
            label.glassEffect(current.inactiveGlass.glass.tint(current.inactiveColor.opacity(current.inactiveOpacity)), in: Capsule())
        }
    }

    private func textStyle(_ choice: TextStyleChoice, color: Color, opacity: Double) -> AnyShapeStyle {
        switch choice {
        case .primary: AnyShapeStyle(.primary)
        case .secondary: AnyShapeStyle(.secondary)
        case .tertiary: AnyShapeStyle(.tertiary)
        case .custom: AnyShapeStyle(color.opacity(opacity))
        }
    }

    @ViewBuilder
    private func textStylePicker(style: Binding<TextStyleChoice>, color: Binding<Color>) -> some View {
        Picker(selection: style) {
            ForEach(TextStyleChoice.allCases) { Text(verbatim: $0.rawValue).tag($0) }
        } label: { Text(verbatim: "Text color") }
        if style.wrappedValue == .custom {
            ColorPicker(selection: color, supportsOpacity: false) {
                Text(verbatim: "Text color · \(color.wrappedValue.hex)")
            }
        }
    }

    private func statusLabel(_ show: Show?) -> String {
        switch show?.status {
        case .ended: "Ended"
        case .upcoming: "Upcoming"
        default: "Running"
        }
    }

    // MARK: - Réglages

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(verbatim: String(format: format, value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func resetToCurrent() {
        if isDark { darkSettings = .currentDark } else { lightSettings = .currentLight }
    }

    private var settingsSummary: String {
        """
        Style Lab, \(selectedShow.label), \(isDark ? "dark" : "light") mode
        Reflection: blur \(Int(current.blur)), opacity \(String(format: "%.2f", current.reflectionOpacity)), saturation \(String(format: "%.2f", current.saturation))
        Pill background: \(backgroundSummary)
        Pill text: \(current.textColor.hex), \(current.weight.rawValue)
        Stroke: \(current.hasStroke ? "on, \(String(format: "%.2f", current.strokeOpacity))" : "off")
        Genres: \(textSummary(current.genresStyle, color: current.genresColor))\(current.genresStyle == .custom ? " at \(String(format: "%.2f", current.genresOpacity))" : ""), \(current.genresWeight.rawValue)
        Inactive pill background: \(inactiveSummary)
        Inactive pill text: \(textSummary(current.inactiveTextStyle, color: current.inactiveTextColor)), \(current.inactiveWeight.rawValue)
        """
    }

    private func textSummary(_ choice: TextStyleChoice, color: Color) -> String {
        choice == .custom ? color.hex : ".\(choice.rawValue.lowercased())"
    }

    private var inactiveSummary: String {
        switch current.inactiveBackground {
        case .fill: ".fill.tertiary"
        case .color: "color \(current.inactiveColor.hex) at \(String(format: "%.2f", current.inactiveOpacity))"
        case .material: "material \(current.inactiveMaterial.rawValue)"
        case .glass: "glass \(current.inactiveGlass.rawValue), tint \(current.inactiveColor.hex) at \(String(format: "%.2f", current.inactiveOpacity))"
        }
    }

    private var backgroundSummary: String {
        switch current.pillBackground {
        case .color: "color \(current.pillColor.hex) at \(String(format: "%.2f", current.pillOpacity))"
        case .material: "material \(current.materialKind.rawValue)"
        case .glass: "glass \(current.glassKind.rawValue), tint \(current.pillColor.hex) at \(String(format: "%.2f", current.pillOpacity))"
        }
    }

    private func loadShows() async {
        for labShow in LabShow.allCases {
            var tmdbID = labShow.tmdbID
            if tmdbID == nil {
                tmdbID = try? await repository.search(query: labShow.label).first?.tmdbID
            }
            guard let tmdbID, let show = try? await repository.getShow(tmdbID: tmdbID) else { continue }
            shows[labShow] = show
        }
    }
}

/// Réglages du banc pour un mode. Valeurs par défaut : celles de l'app (2026-10-26).
private struct LabSettings {
    var blur: Double
    var reflectionOpacity: Double
    var saturation: Double
    var pillBackground: StyleLabView.PillBackground
    var materialKind: StyleLabView.MaterialKind = .regular
    var glassKind: StyleLabView.GlassKind = .regular
    var pillColor: Color = Color(red: 0.910, green: 0.239, blue: 0.620)
    var pillOpacity: Double = 0.15
    var textColor: Color
    var weight: StyleLabView.Weight = .semibold
    var hasStroke = false
    var strokeOpacity: Double = 0.45

    // Genres (valeurs de l'app : .secondary, Regular)
    var genresStyle: StyleLabView.TextStyleChoice = .secondary
    var genresColor: Color = .gray
    var genresOpacity: Double = 1
    var genresWeight: StyleLabView.Weight = .regular

    // Pastille inactive (valeurs de l'app : .fill.tertiary, .secondary, Medium)
    var inactiveBackground: StyleLabView.InactiveBackground = .fill
    var inactiveMaterial: StyleLabView.MaterialKind = .regular
    var inactiveGlass: StyleLabView.GlassKind = .regular
    var inactiveColor: Color = .gray
    var inactiveOpacity: Double = 0.15
    var inactiveTextStyle: StyleLabView.TextStyleChoice = .secondary
    var inactiveTextColor: Color = .gray
    var inactiveWeight: StyleLabView.Weight = .medium

    static let currentLight = LabSettings(
        blur: 40, reflectionOpacity: 0.45, saturation: 1.6,
        pillBackground: .color,
        textColor: Color(red: 0x59 / 255, green: 0x0A / 255, blue: 0x37 / 255)
    )

    static let currentDark = LabSettings(
        blur: 40, reflectionOpacity: 0.55, saturation: 1,
        pillBackground: .color,
        pillOpacity: 0.25,
        textColor: Color(red: 0xF0 / 255, green: 0x7A / 255, blue: 0xBF / 255)
    )
}

private extension Color {
    /// Code hexa (#RRGGBB) de la couleur en sRGB.
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int((min(max(r, 0), 1) * 255).rounded()),
                      Int((min(max(g, 0), 1) * 255).rounded()),
                      Int((min(max(b, 0), 1) * 255).rounded()))
    }
}

#Preview {
    NavigationStack {
        StyleLabView()
    }
    .environment(FollowedShowsStore())
}
#endif
