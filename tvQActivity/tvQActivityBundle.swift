import SwiftUI
import WidgetKit

/// Extension de tvQ : seulement la Live Activity des soirs de diffusion (aucun
/// widget d'écran d'accueil pour l'instant).
@main
struct tvQActivityBundle: WidgetBundle {
    var body: some Widget {
        EpisodeLiveActivity()
    }
}
