import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            form
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(viewModel.isLoading)
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.isLoading)
        .onChange(of: viewModel.didSucceed) { _, succeeded in
            guard succeeded else { return }
            session.refresh()
            dismiss()
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                credentialFields
                messages
                submitButton
                secondaryActions
                separator
                appleButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            // Exportation Icon Composer telle quelle (variante sombre gérée par l'asset).
            Image("tvQAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityLabel(Text(verbatim: "tvQ"))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var credentialFields: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding()
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            SecureField("Password", text: $viewModel.password)
                .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding()
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if let infoMessage = viewModel.infoMessage {
            Text(infoMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(submitTitle)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)
    }

    private var secondaryActions: some View {
        VStack(spacing: 8) {
            if viewModel.mode == .signIn {
                Button("Forgot password?") {
                    focusedField = nil
                    Task { await viewModel.resetPassword() }
                }
                .font(.footnote)
            }

            Button(toggleModeTitle) {
                viewModel.toggleMode()
            }
            .font(.footnote)
        }
        .disabled(viewModel.isLoading)
    }

    private var separator: some View {
        HStack {
            VStack { Divider() }
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack { Divider() }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(viewModel.mode == .signIn ? .signIn : .signUp) { request in
            viewModel.prepareAppleRequest(request)
        } onCompletion: { result in
            Task { await viewModel.signInWithApple(result) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        // Le style n'est lu qu'à la création : on force la recréation au changement de thème.
        .id(colorScheme)
        .frame(height: 50)
        .disabled(viewModel.isLoading)
    }

    // MARK: - Actions

    private func submit() {
        focusedField = nil
        Task { await viewModel.submit() }
    }

    // MARK: - Libellés

    // Typage explicite en LocalizedStringKey : une ternaire de littéraux passée
    // directement à Text() s'infère en String brut (non traduisible), pas en clé.
    private var subtitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Sign in to your account" : "Keep your shows on all your devices"
    }

    private var submitTitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Sign In" : "Sign Up"
    }

    private var toggleModeTitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Don't have an account? Create one" : "Already have an account? Sign in"
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
