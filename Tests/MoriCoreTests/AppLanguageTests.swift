import XCTest
@testable import MoriCore

final class AppLanguageTests: XCTestCase {
    func testSystemLanguageResolutionAndEnglishFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["de-DE"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-CN"]), .english)
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en-US"]), .simplifiedChinese)
    }

    func testLanguagePersistsWithoutChangingExistingAppearanceOrSession() throws {
        let suite = "MoriLanguageTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = Data("existing wallpaper and custom CSS".utf8)
        defaults.set(appearance, forKey: "appearance")
        defaults.set("existing article", forKey: "draft")
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        XCTAssertEqual(AppLanguage.load(from: defaults).resolved(preferredLanguages: ["zh-Hans-CN"]), .english)
        AppLanguage.simplifiedChinese.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults), .simplifiedChinese)
        AppLanguage.english.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        XCTAssertEqual(defaults.data(forKey: "appearance"), appearance)
        XCTAssertEqual(defaults.string(forKey: "draft"), "existing article")
        defaults.set("unknown", forKey: AppLanguage.preferenceKey)
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        AppLanguage.system.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults).resolved(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
    }
}
