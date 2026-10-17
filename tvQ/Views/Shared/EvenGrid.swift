import SwiftUI

/// Grille qui place toujours un nombre pair de colonnes (minimum 2).
///
/// Pourquoi pair : sur un appareil pliable (iPhone Duo), Apple recommande un
/// nombre pair de colonnes pour qu'aucune carte ne chevauche la pliure. On
/// applique la règle partout plutôt que seulement sur ces appareils : la
/// grille garde ainsi la même allure d'un écran à l'autre.
///
/// Pourquoi minimum 2 : même à une grande taille de texte (Dynamic Type), deux
/// affiches côte à côte restent lisibles ; on préfère des cartes un peu plus
/// étroites que minimumWidth à une colonne unique qui étire chaque affiche
/// sur toute la largeur.
///
/// Reste lazy : le body est une LazyVGrid, et seule la largeur proposée par le
/// conteneur est mesurée (pas le contenu), donc aucune cellule n'est créée
/// d'avance.
/// Hors de EvenGrid exprès : une fonction globale nonisolated est Sendable, alors
/// qu'une méthode statique de EvenGrid ne l'est pas (le type contient la closure
/// `cell`, non Sendable). onGeometryChange exige une transformation @Sendable.
nonisolated private func evenGridWidth(of proxy: GeometryProxy) -> CGFloat {
    proxy.size.width
}

struct EvenGrid<Data: RandomAccessCollection, Cell: View>: View
where Data.Element: Identifiable {
    let items: Data
    /// Largeur visée pour une cellule. Sert à calculer combien de colonnes
    /// tiennent ; la largeur réelle s'ajuste ensuite pour remplir la ligne.
    let minimumWidth: CGFloat
    var spacing: CGFloat = 24
    @ViewBuilder var cell: (Data.Element) -> Cell

    @State private var availableWidth: CGFloat = 0

    private var columnCount: Int {
        let fitting = Int((availableWidth + spacing) / (minimumWidth + spacing))
        return max(2, fitting - fitting % 2)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columnCount)
    }


    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                cell(item)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: evenGridWidth(of:)) { newWidth in
            availableWidth = newWidth
        }
    }
}

#Preview {
    struct Item: Identifiable { let id: Int }
    return ScrollView {
        EvenGrid(items: (1...9).map(Item.init), minimumWidth: 150) { item in
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.3))
                .aspectRatio(2/3, contentMode: .fit)
                .overlay { Text("\(item.id)") }
        }
        .padding()
    }
}
