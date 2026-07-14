import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(verbatim: "tvQ")
                            .font(.largeTitle.bold())
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 12) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                            .padding()
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        viewModel.submit()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(submitTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)

                    Button {
                        viewModel.toggleMode()
                    } label: {
                        Text(toggleModeTitle)
                            .font(.footnote)
                    }
                    .disabled(viewModel.isLoading)

                    HStack {
                        VStack { Divider() }
                        Text("or")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        VStack { Divider() }
                    }

                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        viewModel.handleAppleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // Typage explicite en LocalizedStringKey : une ternaire de littéraux passée
    // directement à Text() s'infère en String brut (non traduisible), pas en clé.
    private var subtitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Sign in to continue" : "Create your account"
    }

    private var submitTitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Sign In" : "Sign Up"
    }

    private var toggleModeTitle: LocalizedStringKey {
        viewModel.mode == .signIn ? "Don't have an account? Sign up" : "Already have an account? Sign in"
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
