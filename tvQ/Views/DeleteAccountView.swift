import SwiftUI
import AuthenticationServices

/// Suppression de compte (exigée par l'App Store dès qu'une app permet d'en créer un).
/// Feuille modale : explique la portée, demande une confirmation d'identité
/// (Firebase exige une connexion récente pour supprimer un compte), puis supprime.
/// Au succès, le compte disparaît et RootView ramène l'app à LoginView.
struct DeleteAccountView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var showingFinalConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your account and the list of shows you follow. This can't be undone.")
                }

                if authViewModel.usesAppleSignIn {
                    Section {
                        SignInWithAppleButton(
                            .continue,
                            onRequest: authViewModel.prepareAppleReauthRequest,
                            onCompletion: { result in
                                Task { await authViewModel.deleteAccount(withApple: result) }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                    } footer: {
                        Text("Confirm with Apple to delete your account.")
                    }
                } else {
                    Section {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    } footer: {
                        Text("Enter your password to confirm.")
                    }

                    Section {
                        Button("Delete My Account", role: .destructive) {
                            showingFinalConfirmation = true
                        }
                        .disabled(password.isEmpty)
                    }
                }

                if let message = authViewModel.deletionErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(authViewModel.isDeletingAccount)
            .overlay {
                if authViewModel.isDeletingAccount {
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showingFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await authViewModel.deleteAccount(password: password) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
        .interactiveDismissDisabled(authViewModel.isDeletingAccount)
    }
}

#Preview {
    DeleteAccountView()
        .environment(AuthViewModel())
}
