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
                VStack(alignment: .leading, spacing: 8) {
                    // Icône de l'app exportée d'Icon Composer (variantes Default et Dark,
                    // tvQlogo.icon) : à réexporter si l'icône change. Le .icon lui-même ne
                    // peut pas s'afficher dans l'app, Xcode n'en fait qu'une icône système.
                    Image("tvQAppIcon")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityLabel(Text(verbatim: "tvQ"))
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

            // Logiciels libres : texte complet de chaque licence (Apache 2.0, BSD,
            // OpenSSL, zlib...), exigé par ces licences pour une distribution binaire.
            Section {
                Text("tvQ uses open-source software, including the Firebase SDK for iOS.")
                    .font(.callout)
                NavigationLink("Acknowledgements") {
                    AcknowledgementsView()
                }
            } header: {
                Text("Open-source software")
            }

            Section {
                if let url = URL(string: "mailto:tvq.app.support@gmail.com") {
                    Link("Contact", destination: url)
                }
                // Page hébergée sur GitHub Pages (dépôt tchendoh/tvq-site), même URL
                // que dans App Store Connect.
                if let url = URL(string: "https://tchendoh.github.io/tvq-site/privacy.html") {
                    Link("Privacy Policy", destination: url)
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
