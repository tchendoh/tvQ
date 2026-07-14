import SwiftUI

/// Placeholder — l'accueil "À venir" attend une couche de cache et un filtrage
/// par ShowStatus avant de générer l'horaire (voir discussion en cours).
struct UpcomingView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Coming soon",
                systemImage: "calendar",
                description: Text("Your upcoming episodes will show up here.")
            )
            .navigationTitle("Upcoming")
            .settingsToolbarItem()
        }
    }
}

#Preview {
    UpcomingView()
}
