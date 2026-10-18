import XCTest

/// Seul test d'interface gardé : il mesure le temps de lancement (Instruments donne
/// le détail). Lent (environ 1,5 min, 5 lancements) : à lancer à la demande depuis
/// le Test Navigator, pas à chaque ⌘U.
final class LaunchPerformanceTests: XCTestCase {
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
