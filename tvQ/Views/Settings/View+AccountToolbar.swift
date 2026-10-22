import SwiftUI

extension View {
    /// Avatar du compte en haut à droite, identique sur tous les onglets, sur le
    /// modèle d'App Store et de Music : il ouvre AccountView dans une feuille qui
    /// semble sortir de l'avatar. Nécessite d'être appelé à l'intérieur du
    /// NavigationStack de chaque onglet.
    func accountToolbarItem() -> some View {
        modifier(AccountToolbarItem())
    }
}

private struct AccountToolbarItem: ViewModifier {
    @Environment(SessionStore.self) private var session
    @State private var isPresentingAccount = false
    @Namespace private var transition

    private static let transitionID = "account"

    func body(content: Content) -> some View {
        content
            .toolbar {
                if #available(iOS 27.1, *) {
                    // Vue personnalisée : sans ceci, elle resterait dans la barre horizontale.
                    accountItem
                        .axisBehavior(.verticalPreferred)
                } else {
                    accountItem
                }
            }
            .sheet(isPresented: $isPresentingAccount) {
                NavigationStack {
                    AccountView()
                }
                .navigationTransition(.zoom(sourceID: Self.transitionID, in: transition))
            }
    }

    /// Placement par défaut : en haut à droite sur iPhone, dans la colonne
    /// verticale sur iPhone Duo (comme le ProfileView d'Apple, Tech Talk 111462).
    /// Bouton de verre de la barre, comme les autres, avec la silhouette ou les
    /// initiales en rose (AccountAvatar, style .glyph) plutôt qu'un disque rose
    /// plein : la couleur pleine est réservée à l'action principale.
    private var accountItem: some ToolbarContent {
        ToolbarItem {
            Button {
                isPresentingAccount = true
            } label: {
                AccountAvatar(user: session.currentUser, size: 32, style: .glyph)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: Self.transitionID, in: transition)
            .accessibilityLabel(Text("Account"))
        }
    }
}
