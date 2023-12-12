//
//  AuthManager.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-27.
//
//  Source : https://medium.com/@marwa.diab/firebase-authentication-in-swiftui-part-3-80be99dbc63d

import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import Observation

enum AuthState {
    case authenticated // Anonymously authenticated in Firebase
    case signedIn // Authenticated in Firebase using one of service providers, and not anonymous
    case signedOut // Not authenticated in Firebase
}

/// An environment singleton responsible for handling
/// Firebase authentication in app.
@Observable
class AuthManager {

    static let shared = AuthManager()

    /// Current Firebase auth user.
    var user: User?
    
    /// Auth state for current user.
    var authState = AuthState.signedOut
    
    /// Auth state listener handler
    private var authStateHandle: AuthStateDidChangeListenerHandle!
    
    /// Common auth link errors.
    private let authLinkErrors: [AuthErrorCode.Code] = [
        .emailAlreadyInUse,
        .credentialAlreadyInUse,
        .providerAlreadyLinked
    ]
    
    private init() {
        // Start listening to auth changes.
        configureAuthStateChanges()
    }
    
    // MARK: - Auth State
    /// Add listener for changes in the authorization state.
    func configureAuthStateChanges() {
        authStateHandle = Auth.auth().addStateDidChangeListener { auth, user in
            Task {
                await self.updateState(user: user)
            }
        }
    }
    
    /// Remove listener for changes in the authorization state.
    func removeAuthStateListener() {
        Auth.auth().removeStateDidChangeListener(authStateHandle)
    }
    
    /// Update auth state for given user.
    /// - Parameter user: `Optional` firebase user.
    func updateState(user: User?) async {
        await MainActor.run {
            self.user = user
            let isAuthenticatedUser = user != nil
            let isAnonymous = user?.isAnonymous ?? false
            
            if isAuthenticatedUser {
                self.authState = isAnonymous ? .authenticated : .signedIn
            } else {
                self.authState = .signedOut
            }
        }
    }
    
    //MARK: - Authenticate
    private func authenticateUser(credentials: AuthCredential) async throws -> AuthDataResult? {
        // If we have authenticated user, then link with given credentials.
        // Otherwise, sign in using given credentials.
        if Auth.auth().currentUser != nil {
            return try await authLink(credentials: credentials)
        } else {
            return try await authSignIn(credentials: credentials)
        }
    }
    
    func appleAuth(
        _ appleIDCredential: ASAuthorizationAppleIDCredential,
        nonce: String?
    ) async throws -> AuthDataResult? {
        guard let nonce = nonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identity token")
            return nil
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return nil
        }
        
        // Initialize a Firebase credential, including the user's full name.
        let credentials = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                        rawNonce: nonce,
                                                        fullName: appleIDCredential.fullName)
        
        do {
            return try await authenticateUser(credentials: credentials)
        }
        catch {
            print("FirebaseAuthError: appleAuth(appleIDCredential:nonce:) failed. \(error)")
            throw error
        }
    }
    
    // MARK: - Sign-in
    
    private func authSignIn(credentials: AuthCredential) async throws -> AuthDataResult? {
        do {
            let result = try await Auth.auth().signIn(with: credentials)
            await updateState(user: result.user)
            return result
        }
        catch {
            print("FirebaseAuthError: signIn(with:) failed. \(error)")
            throw error
        }
    }
    
    private func authLink(credentials: AuthCredential) async throws -> AuthDataResult? {
        do {
            guard let user = Auth.auth().currentUser else { return nil }
            let result = try await user.link(with: credentials)
            await updateState(user: result.user)
            return result
        }
        catch {
            print("FirebaseAuthError: link(with:) failed, \(error)")
            if let error = error as NSError? {
                if let code = AuthErrorCode.Code(rawValue: error.code),
                    authLinkErrors.contains(code) {
                    
                    // If provider is "apple.com", get updated AppleID credentials from the error object.
                    let appleCredentials =
                    credentials.provider == "apple.com"
                    ? error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
                    : nil
                    
                    return try await self.authSignIn(credentials: appleCredentials ?? credentials)
                }
            }
            throw error
        }
    }
    
    @discardableResult
    func signInAnonymously() async throws -> AuthDataResult? {
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.authState = .authenticated
            print("FirebaseAuthSuccess: Sign in anonymously, UID:(\(String(describing: result.user.uid)))")
            return result
        }
        catch {
            print("FirebaseAuthError: failed to sign in anonymously: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sign Out
    /// Sign out a user from Firebase Provider.
    func firebaseProviderSignOut(_ user: User) {
        let providers = user.providerData
            .map { $0.providerID }.joined(separator: ", ")
        
        if providers.contains("apple.com")  {
            // TODO: Sign out from Apple
        }
    }
    
    /// Sign out current `Firebase` auth user
    func signOut() async throws {
        if let user = Auth.auth().currentUser {
            // Sign out current authenticated user in Firebase
            do {
                firebaseProviderSignOut(user)
                try Auth.auth().signOut()
                self.authState = .signedOut
            }
            catch let error as NSError {
                print("FirebaseAuthError: failed to sign out from Firebase, \(error)")
                throw error
            }
        }
    }
}

