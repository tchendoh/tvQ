import SwiftUI
import AuthenticationServices

/// Suppression de compte (exigée par l'App Store dès qu'une app permet d'en créer un).
/// Feuille modale : explique la portée, demande une confirmation d'identité
/// (Firebase exige une connexion récente pour supprimer un compte), puis supprime.
/// Au succès, le compte disparaît et RootView ramène l'app à LoginView.
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DeleteAccountViewModel

    @State private var password = ""
    @State private var isPresentingFinalConfirmation = false

    init(userID: String) {
        _viewModel = State(initialValue: DeleteAccountViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your account and the list of shows you follow. This can't be undone.")
                }

                if viewModel.usesAppleSignIn {
                    Section {
                        SignInWithAppleButton(
                            .continue,
                            onRequest: viewModel.prepareAppleRequest,
                            onCompletion: { result in
                                Task { await viewModel.deleteAccount(withApple: result) }
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
                            isPresentingFinalConfirmation = true
                        }
                        .disabled(password.isEmpty)
                    }
                }

                if let message = viewModel.errorMessage {
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
            .disabled(viewModel.isDeleting)
            .overlay {
                if viewModel.isDeleting {
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $isPresentingFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await viewModel.deleteAccount(password: password) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
        .interactiveDismissDisabled(viewModel.isDeleting)
    }
}

#Preview {
    DeleteAccountView(userID: "preview")
}
