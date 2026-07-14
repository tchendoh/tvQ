import Foundation

/// Point d'accès unique aux clés d'API. La vraie valeur vit dans Config/Secrets.xcconfig
/// (jamais commité), et une phase de build ("Générer Secrets.generated.swift") régénère
/// Config/Secrets.generated.swift à chaque compilation à partir de cette variable —
/// voir cette phase dans Build Phases si vous voulez en revoir le script.
enum APIConfig {
    static var tmdbAPIKey: String {
        Secrets.tmdbAPIKey
    }
}
