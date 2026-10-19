import Foundation
import os
import FirebaseCrashlytics

/// Journaux de l'app, à filtrer par catégorie dans la console de Xcode ou dans
/// l'app Console du Mac (appareil branché). Remplace les `print`.
///
/// Les erreurs quittent aussi l'appareil : chaque `error` ajoute une ligne au fil
/// d'Ariane Crashlytics (jointe au prochain rapport), et `report: true` envoie en plus
/// une erreur non fatale, visible dans la console Firebase avec le nombre
/// d'utilisateurs touchés.
///
/// Règle : les messages sont publics (lisibles dans le journal et dans Crashlytics).
/// Identifiants de série, chemins, codes : oui. Courriel, jeton, identifiant
/// d'utilisateur, texte saisi : jamais.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "tvQ"

    /// Chaque appel réseau : hôte, chemin, code HTTP, taille et durée.
    static let network = AppLogger(subsystem: subsystem, category: "network")
    /// Firestore, SwiftData et données de l'utilisateur.
    static let data = AppLogger(subsystem: subsystem, category: "data")
    /// Notifications et Live Activities.
    static let notifications = AppLogger(subsystem: subsystem, category: "notifications")
}

nonisolated struct AppLogger: Sendable {
    private let logger: Logger
    private let category: String

    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    /// Détail pour le développement ; pas conservé, visible seulement en direct.
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    /// Événement normal, utile pour comprendre (ex. rafraîchissement échoué hors ligne).
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Événement normal mais notable, conservé sur l'appareil.
    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    /// Quelque chose a échoué. Journal local + fil d'Ariane Crashlytics.
    /// - Parameter report: envoie aussi une erreur non fatale à Crashlytics. À réserver
    ///   aux échecs qui révèlent un vrai problème (règles Firestore, base locale),
    ///   pas à ceux qui arrivent normalement (hors ligne, permission refusée).
    func error(_ message: String, _ error: Error? = nil, report: Bool = false) {
        let text = error.map { "\(message) : \($0)" } ?? message
        logger.error("\(text, privacy: .public)")
        Crashlytics.crashlytics().log("[\(category)] \(text)")
        if report, let error {
            Crashlytics.crashlytics().record(error: error, userInfo: ["context": "[\(category)] \(message)"])
        }
    }
}
