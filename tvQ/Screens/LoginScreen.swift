//
//  LoginScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-27.
//

import AuthenticationServices
import SwiftUI

struct LoginScreen: View {
    @Environment(AuthManager.self) private var authManager: AuthManager

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                
                // MARK: - Apple
                SignInWithAppleButton(
                    onRequest: { request in
                        AppleSignInManager.shared.requestAppleAuthorization(request)
                    },
                    onCompletion: { result in
                        handleAppleID(result)
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .light ? .black : .white)
                .frame(width: 280, height: 45, alignment: .center)
                
                // MARK: - Anonymous
                // Hide `Skip` button if user is anonymous.
                if authManager.authState == .signedOut {
                    Button {
                        signAnonymously()
                    } label: {
                        Text("Sign in anonymously")
                            .font(.body.bold())
                            .frame(width: 280, height: 45, alignment: .center)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("tvQBlue"))
        }
    }
    
    func handleAppleID(_ result: Result<ASAuthorization, Error>) {
        if case let .success(auth) = result {
            guard let appleIDCredentials = auth.credential as? ASAuthorizationAppleIDCredential else {
                print("AppleAuthorization failed: AppleID credential not available")
                return
            }
            
            Task {
                do {
                    let result = try await authManager.appleAuth(
                        appleIDCredentials,
                        nonce: AppleSignInManager.nonce
                    )
                    if let _ = result {
                        dismiss()
                    }
                } catch {
                    print("AppleAuthorization failed: \(error)")
                    // Here you can show error message to user.
                }
            }
        }
        else if case let .failure(error) = result {
            print("AppleAuthorization failed: \(error)")
            // Here you can show error message to user.
        }
    }
    
    /// Sign-in anonymously
    func signAnonymously() {
        Task {
            do {
                let result = try await authManager.signInAnonymously()
                print("SignInAnonymouslySuccess: \(result?.user.uid ?? "N/A")")
            }
            catch {
                print("SignInAnonymouslyError: \(error)")
            }
        }
    }
}

#Preview {
    LoginScreen()
        .environment(AuthManager.shared)
}
