import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("tvQ")
                        .font(.title2.bold())
                    Text("Version \(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Attribution TMDB : texte obligatoire selon les API Terms of Use
            // (themoviedb.org/api-terms-of-use), à placer dans une section
            // "About"/"Credits". Logo officiel (themoviedb.org/about/logos-attribution)
            // en Assets.xcassets (TMDbLogo), affiché moins en évidence que le
            // branding de tvQ, conformément à leurs conditions.
            Section {
                Image("TMDbLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                    .accessibilityHidden(true)
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.callout)
                if let url = URL(string: "https://www.themoviedb.org") {
                    Link("themoviedb.org", destination: url)
                        .font(.callout)
                }
            } header: {
                Text("The Movie Database (TMDB)")
            }

            // Attribution TVmaze : licence CC BY-SA, satisfaite par un lien
            // vers tvmaze.com (voir tvmaze.com/api).
            Section {
                Text("Show and episode schedule data provided by TVmaze under CC BY-SA.")
                    .font(.callout)
                if let url = URL(string: "https://www.tvmaze.com") {
                    Link("tvmaze.com", destination: url)
                        .font(.callout)
                }
            } header: {
                Text("TVmaze")
            }

            // Mention IMDb : même logo officiel déjà utilisé dans ShowDetailView,
            // conformément à la trousse de marque IMDb (brand.imdb.com).
            Section {
                HStack(spacing: 6) {
                    Image("IMDbLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 16)
                        .accessibilityHidden(true)
                    Text("Show links open the corresponding IMDb title page.")
                        .font(.callout)
                }
            } header: {
                Text("IMDb")
            }

            // Attribution JustWatch : source des données de "Où regarder" (voir
            // ShowDetailView.watchAvailabilitySection). Requis par TMDB pour
            // l'usage de leur endpoint /watch/providers (voir developer.themoviedb.org).
            Section {
                Text("Where-to-watch information is provided by JustWatch.")
                    .font(.callout)
                if let url = URL(string: "https://www.justwatch.com") {
                    Link("justwatch.com", destination: url)
                        .font(.callout)
                }
            } header: {
                Text("JustWatch")
            }

            Section {
                if let url = URL(string: "mailto:tchendoh@gmail.com") {
                    Link("Contact", destination: url)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("tvQ is not endorsed, certified, or otherwise approved by TMDB, TVmaze, IMDb, or JustWatch.")
            }
        }
        .navigationTitle("About")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
