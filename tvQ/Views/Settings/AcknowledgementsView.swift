import SwiftUI

/// Logiciel libre intégré à tvQ, avec le texte complet de sa licence.
/// Source : `Acknowledgements.json`, généré à partir de `Package.resolved`
/// (fichiers LICENSE de chaque dépôt, à la version utilisée). À régénérer
/// quand les paquets changent (voir BACKLOG.md, « Licences »).
struct Acknowledgement: Decodable, Identifiable, Hashable {
    let name: String
    let url: URL
    let license: String
    let text: String

    var id: String { name }

    static func loadAll(from bundle: Bundle = .main) -> [Acknowledgement] {
        guard let fileURL = bundle.url(forResource: "Acknowledgements", withExtension: "json"),
              let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([Acknowledgement].self, from: data) else {
            return []
        }
        return items
    }
}

struct AcknowledgementsView: View {
    private let items = Acknowledgement.loadAll()

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.name)
                            Text(verbatim: item.license)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("tvQ includes the following open-source software. Tap an item to read its full license.")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationDestination(for: Acknowledgement.self) { item in
            AcknowledgementDetailView(item: item)
        }
    }
}

private struct AcknowledgementDetailView: View {
    let item: Acknowledgement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Link(destination: item.url) {
                    Text(verbatim: item.url.absoluteString)
                        .font(.footnote)
                }
                // Texte de licence non traduit : il doit rester tel quel.
                Text(verbatim: item.text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(Text(verbatim: item.name))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
