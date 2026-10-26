import XCTest

/// Captures d'écran du README (dossier Screenshots/). À lancer à la demande depuis le
/// Test Navigator, comme LaunchPerformanceTests, pas à chaque ⌘U.
///
/// Aucune donnée fictive : le test utilise l'état réel du simulateur. Avant de le
/// lancer, suivre quelques séries dans l'app sur ce simulateur (les données restent
/// entre deux lancements de test).
///
/// Publier ensuite avec ./Screenshots/publish.sh : export du dernier résultat de test
/// (Screenshots/raw/, ignoré par Git), renommage d'après les noms ci-dessous,
/// réduction à 600 px et copie dans le dépôt tvq-site (screenshots/), qui sert les
/// images des README, puis commit et poussée sur confirmation.
final class ReadmeScreenshotsTests: XCTestCase {
    private var app: XCUIApplication!

    /// Une passe par langue : README.md (anglais) et README.fr.md (français).
    /// Libellés des onglets tels qu'ils apparaissent dans Localizable.xcstrings.
    private struct Language {
        let code: String
        let locale: String
        let home: String
        let schedule: String
        let myShows: String
        let search: String
    }

    private let languages = [
        Language(code: "en", locale: "en_CA", home: "Home", schedule: "Schedule", myShows: "My Shows", search: "Search"),
        Language(code: "fr", locale: "fr_CA", home: "Accueil", schedule: "Horaire", myShows: "Mes séries", search: "Recherche"),
    ]

    /// Série montrée dans la fiche (titre ou partie du titre, tel qu'affiché dans
    /// My Shows). Choisir une série suivie avec une belle affiche.
    private static let featuredShow = "Severance"

    /// Requête montrée dans la capture de Search : choisir un mot qui donne une
    /// grille d'affiches variées.
    private static let searchQuery = "Star Wars"

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testReadmeScreenshots() {
        followFeaturedShowIfNeeded()
        for language in languages {
            for appearance in [XCUIDevice.Appearance.light, .dark] {
                shoot(language, appearance)
            }
        }
    }

    @MainActor
    private func shoot(_ language: Language, _ appearance: XCUIDevice.Appearance) {
        app = XCUIApplication()
        // Le mode est imposé à l'app elle-même, en plus de l'appareil : son réglage
        // Account › Appearance (clé settings.appearance, appliqué par RootView avec
        // preferredColorScheme) l'emporte sur l'appareil. Resté sur « Light » dans le
        // simulateur, il donnait une rangée « Dark » entièrement claire. Un argument
        // de lancement ne vaut que pour ce lancement : le réglage enregistré est intact.
        let mode = appearance == .dark ? "dark" : "light"
        app.launchArguments += ["-AppleLanguages", "(\(language.code))", "-AppleLocale", language.locale]
        app.launchArguments += ["-settings.appearance", mode]
        XCUIDevice.shared.appearance = appearance
        let suffix = "\(language.code)-\(mode)"
        app.launch()

        capture("home-\(suffix)", afterTapping: language.home)
        capture("schedule-\(suffix)", afterTapping: language.schedule)
        captureSearch("search-\(suffix)", tab: language.search)
        capture("my-shows-\(suffix)", afterTapping: language.myShows)

        // Fiche : la série vedette si elle est suivie, sinon la première de My Shows.
        // Les cartes portent l'identifiant « showCard » (MyShowsView) ; sans lui, le
        // premier bouton trouvé est l'en-tête de section, qui replie la section.
        let cards = app.buttons.matching(identifier: "showCard")
        let featured = cards.matching(NSPredicate(format: "label CONTAINS[c] %@", Self.featuredShow)).firstMatch
        let show = featured.waitForExistence(timeout: 5) ? featured : cards.firstMatch
        if show.waitForExistence(timeout: 5) {
            show.tap()
            settle()
            snapshot("show-detail-\(suffix)")
        }
        app.terminate()
    }

    /// Suit la série vedette depuis Search si elle ne l'est pas déjà, pour que la
    /// fiche montrée soit toujours la même, quel que soit le simulateur.
    @MainActor
    private func followFeaturedShowIfNeeded() {
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_CA"]
        app.launch()

        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.waitForExistence(timeout: 10) { searchTab.tap() }
        let field = app.searchFields.firstMatch
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("Champ de recherche introuvable")
            return app.terminate()
        }
        field.tap()
        field.typeText(Self.featuredShow + "\n")

        // Badge de suivi du premier résultat : « Follow » s'il n'est pas suivi,
        // « Following » s'il l'est déjà.
        let follow = app.buttons["Follow"].firstMatch
        let following = app.buttons["Following"].firstMatch
        if follow.waitForExistence(timeout: 10), !following.exists {
            follow.tap()
            settle()
        }
        app.terminate()
    }

    @MainActor
    private func captureSearch(_ name: String, tab: String) {
        let button = app.tabBars.buttons[tab]
        if button.waitForExistence(timeout: 10) { button.tap() }
        let field = app.searchFields.firstMatch
        guard field.waitForExistence(timeout: 10) else {
            return XCTFail("Champ de recherche introuvable (\(tab))")
        }
        field.tap()
        field.typeText(Self.searchQuery)
        settle()
        // Ferme le clavier pour montrer la grille entière.
        app.swipeUp()
        app.swipeDown()
        settle()
        snapshot(name)
    }

    @MainActor
    private func capture(_ name: String, afterTapping tab: String) {
        let button = app.tabBars.buttons[tab]
        if button.waitForExistence(timeout: 10) { button.tap() }
        settle()
        snapshot(name)
    }

    /// Laisse le temps aux affiches (réseau) de s'afficher.
    @MainActor
    private func settle() {
        sleep(4)
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
