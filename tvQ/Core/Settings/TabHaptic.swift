import SwiftUI

/// Vibration jouée au changement d'onglet (et au retour sur « Aujourd'hui » par un
/// deuxième toucher sur Schedule). Réglage interne : modifiable seulement dans
/// Settings › Debug ; les autres builds utilisent `AppRules.Haptics.tabDefault`.
nonisolated enum TabHaptic: String, CaseIterable, Identifiable {
    case off
    /// La plus légère, prévue par Apple pour un changement de choix.
    case selection
    case light
    case medium
    case heavy
    case soft
    case solid
    case rigid

    var id: String { rawValue }

    /// Nom affiché dans la page Debug (non traduit).
    var label: String {
        switch self {
        case .off: "Off"
        case .selection: "Selection"
        case .light: "Impact light"
        case .medium: "Impact medium"
        case .heavy: "Impact heavy"
        case .soft: "Flexibility soft"
        case .solid: "Flexibility solid"
        case .rigid: "Flexibility rigid"
        }
    }

    /// `.selection` n'a pas de réglage d'intensité.
    var supportsIntensity: Bool {
        switch self {
        case .off, .selection: false
        default: true
        }
    }

    /// `nil` : aucune vibration.
    func feedback(intensity: Double) -> SensoryFeedback? {
        switch self {
        case .off: nil
        case .selection: .selection
        case .light: .impact(weight: .light, intensity: intensity)
        case .medium: .impact(weight: .medium, intensity: intensity)
        case .heavy: .impact(weight: .heavy, intensity: intensity)
        case .soft: .impact(flexibility: .soft, intensity: intensity)
        case .solid: .impact(flexibility: .solid, intensity: intensity)
        case .rigid: .impact(flexibility: .rigid, intensity: intensity)
        }
    }
}
