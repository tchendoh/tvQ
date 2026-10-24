import SwiftUI

#if DEBUG
/// Settings › Debug › Trends : contenu brut de trends/current, en attendant une
/// vraie page publique (quand les chiffres auront du sens). Textes non traduits.
struct TrendsDebugView: View {
    @State private var trends: Trends?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var list: TrendsList = .mostFollowed

    private let service = TrendsService()

    enum TrendsList: String, CaseIterable, Identifiable {
        case mostFollowed = "Most followed"
        case rising = "Rising"
        var id: Self { self }
    }

    var body: some View {
        Form {
            if let errorMessage {
                Section { Text(verbatim: errorMessage).foregroundStyle(.red) }
            } else if let trends {
                summarySection(trends)
                Section {
                    Picker(selection: $list) {
                        ForEach(TrendsList.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                    } label: { EmptyView() }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                entriesSection(trends)
            } else if !isLoading {
                Section { Text(verbatim: "trends/current does not exist yet.") }
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .navigationTitle(Text(verbatim: "Trends"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func summarySection(_ trends: Trends) -> some View {
        Section {
            LabeledContent { Text(trends.updatedAt, format: .dateTime) } label: { Text(verbatim: "Updated") }
            LabeledContent { Text(trends.userCount, format: .number) } label: { Text(verbatim: "Users") }
            LabeledContent { Text(verbatim: risingDescription(trends)) } label: { Text(verbatim: "Rising window") }
        }
    }

    private func risingDescription(_ trends: Trends) -> String {
        switch trends.risingMethod {
        case .snapshot: "\(trends.risingDays) days, net change since \(trends.risingSince ?? "?")"
        case .addedAt: "\(trends.risingDays) days, by date added (no old snapshot yet)"
        }
    }

    @ViewBuilder
    private func entriesSection(_ trends: Trends) -> some View {
        Section {
            switch list {
            case .mostFollowed:
                if trends.mostFollowed.isEmpty { Text(verbatim: "Empty.") }
                ForEach(Array(trends.mostFollowed.enumerated()), id: \.element) { index, entry in
                    TrendsDebugRow(rank: index + 1, showID: entry.showID, value: "\(entry.followers)")
                }
            case .rising:
                if trends.rising.isEmpty { Text(verbatim: "Empty.") }
                ForEach(Array(trends.rising.enumerated()), id: \.element) { index, entry in
                    TrendsDebugRow(rank: index + 1, showID: entry.showID, value: "+\(entry.gained)")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trends = try await service.current()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Une ligne : rang, titre résolu par ShowRepository (caches à 3 paliers, chargé
/// seulement quand la ligne apparaît), et la valeur.
private struct TrendsDebugRow: View {
    let rank: Int
    let showID: String
    let value: String
    @State private var title: String?

    var body: some View {
        HStack {
            Text(verbatim: "\(rank).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .trailing)
            Text(verbatim: title ?? "#\(showID)")
                .lineLimit(1)
            Spacer()
            Text(verbatim: value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .task(id: showID) {
            guard let tmdbID = Int(showID) else { return }
            title = try? await ShowRepository.shared.getShow(tmdbID: tmdbID).title
        }
    }
}
#endif
