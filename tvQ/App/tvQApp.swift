//
//  tvQApp.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2026-07-11.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import UserNotifications

/// App Check : Firestore n'accepte que les requêtes venant de la vraie app tvQ.
/// - Release (vrais appareils) : App Attest, attestation signée par Apple.
/// - Debug (simulateur compris, qui ne peut pas faire d'App Attest) : fournisseur de
///   débogage, avec un jeton fixe tiré de Secrets.xcconfig (hors Git) et enregistré
///   dans la console Firebase. Le même jeton sert pour tous les simulateurs.
///
/// nonisolated : Firebase peut appeler la fabrique hors du fil principal.
nonisolated final class TvQAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        // Clé lue par AppCheckDebugProvider. Sans elle, le SDK génère un jeton
        // aléatoire par appareil, à réenregistrer dans la console à chaque fois.
        // Depuis AppCheckCore réécrit en Swift (Firebase 12.x), la clé UserDefaults
        // est « GACAppCheckDebugToken »
        if !Secrets.appCheckDebugToken.isEmpty {
            UserDefaults.standard.set(Secrets.appCheckDebugToken, forKey: "GACAppCheckDebugToken")
        }
        #endif
        AppSettings.migrateLegacyContentLanguage()
        // Doit précéder FirebaseApp.configure().
        AppCheck.setAppCheckProviderFactory(TvQAppCheckProviderFactory())
        FirebaseApp.configure()
        // Lance tout de suite le chargement du jeton TMDB (voir TMDBToken).
        Task { await TMDBToken.shared.prefetch() }
        // Tôt, pour recevoir aussi le toucher qui a lancé l'app.
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// App au premier plan : afficher quand même la notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Toucher : ouvrir la fiche de la série.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let tmdbID = response.notification.request.content.userInfo[NotificationRouter.tmdbIDKey] as? Int
        else { return }
        await MainActor.run { NotificationRouter.shared.tmdbID = tmdbID }
    }
}

@main
struct tvQApp: App {
    // Enregistre l'app delegate pour l'initialisation de Firebase au démarrage.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
