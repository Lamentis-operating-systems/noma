@testable import Noma
import Foundation
import XCTest

final class LocalizationCatalogTests: XCTestCase {
    func testCatalogHasNoStaleOrRetiredProductKeys() throws {
        let catalog = try loadCatalog()

        XCTAssertTrue(catalog.strings.values.allSatisfy { $0.extractionState != "stale" })
        XCTAssertNil(catalog.strings["create.project.empty.add-button"])
        XCTAssertNil(catalog.strings["settings.appearance.mode"])
    }

    func testEveryProductKeyHasEnglishAndGermanValues() throws {
        let catalog = try loadCatalog()
        let productEntries = catalog.strings.filter { key, _ in
            key.contains(".") && !key.hasPrefix("%")
        }

        XCTAssertFalse(productEntries.isEmpty)
        for (key, entry) in productEntries {
            for language in ["en", "de"] {
                let value = entry.localizations?[language]?.stringUnit.value
                XCTAssertFalse(
                    value?.isEmpty ?? true,
                    "Missing \(language) localization for \(key)"
                )
            }
        }
    }

    func testHomeEmptySubtitleUsesTaskOnlyCopyInBothLocales() throws {
        let entry = try XCTUnwrap(loadCatalog().strings["home.empty.subtitle"])

        XCTAssertEqual(
            entry.localizations?["en"]?.stringUnit.value,
            "Create a task to start shaping your day here."
        )
        XCTAssertEqual(
            entry.localizations?["de"]?.stringUnit.value,
            "Erstelle eine Aufgabe, damit dein Tag hier Gestalt annimmt."
        )
    }

    func testNotificationSettingsLocalizationKeysAreRemoved() throws {
        let strings = try loadCatalog().strings

        XCTAssertNil(strings["settings.notifications.close.accessibility-label"])
        XCTAssertNil(strings["settings.notifications.daily-planning"])
        XCTAssertNil(strings["settings.notifications.open-tasks"])
        XCTAssertNil(strings["settings.notifications.section-title"])
        XCTAssertNil(strings["settings.notifications.time"])
    }

    func testRecurrenceManagerOnlyLocalizationKeysAreRemoved() throws {
        let strings = try loadCatalog().strings

        XCTAssertNil(strings["recurrence.close"])
        XCTAssertNil(strings["recurrence.stop.explanation"])
    }

    private func loadCatalog() throws -> Catalog {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryURL.appendingPathComponent("Noma/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))
    }
}

private struct Catalog: Decodable {
    let strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    let extractionState: String?
    let localizations: [String: CatalogLocalization]?
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit
}

private struct CatalogStringUnit: Decodable {
    let value: String
}
