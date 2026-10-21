import SwiftUI

/// Settings › Account (vrai compte seulement : en session anonyme, la carte de
/// compte ouvre directement LoginView).
struct AccountSettingsView: View {
    @Environment(SessionStore.self) private var session

    @State private var isPresentingDeleteAccount = false
    @State private var signOutFailed = false

    var body: some View {
        Form {
            if let user = session.currentUser {
                Section {
                    HStack(spacing: 14) {
                        AccountAvatar(user: user, size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = user.displayName {
                                Text(name).font(.headline)
                            }
                            Text(user.email)
                                .foregroundStyle(user.displayName == nil ? .primary : .secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    LabeledContent("Signed in with") {
                        Text(signInMethodName)
                    }
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    do {
                        try session.signOut()
                    } catch {
                        signOutFailed = true
                    }
                }
            }

            Section {
                Button("Delete Account", role: .destructive) {
                    isPresentingDeleteAccount = true
                }
            } footer: {
                Text("Permanently deletes your account and the shows you follow.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingDeleteAccount) {
            if let user = session.currentUser {
                DeleteAccountView(userID: user.id)
            }
        }
        .alert("Sign out failed.", isPresented: $signOutFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var signInMethodName: LocalizedStringKey {
        switch session.signInMethod {
        case .apple: "Apple"
        case .password: "Email"
        case .other: "Other"
        }
    }
}
