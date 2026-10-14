import XCTest
@testable import MyBasics

@MainActor
final class CurrencyFormatterTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let spain = Locale(identifier: "es_ES")

    func testFormatsWithDeviceSeparators() {
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 450_000, currency: "USD", locale: us), "$4,500.00")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 1_250, currency: "USD", locale: us), "$12.50")
        // En España el punto separa miles y la coma, decimales.
        XCTAssertTrue(CurrencyFormatter.string(fromCents: 450_000, currency: "USD", locale: spain).hasPrefix("4500,00")
            || CurrencyFormatter.string(fromCents: 450_000, currency: "USD", locale: spain).hasPrefix("4.500,00"))
    }

    func testTypingFourThousandFiveHundredIsNotFourPointFive() {
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "4500", currency: "USD", locale: us), 450_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "4500", currency: "USD", locale: spain), 450_000)
    }

    func testParsesDecimalsWithLocaleSeparator() {
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "12.5", currency: "USD", locale: us), 1_250)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "12,5", currency: "USD", locale: spain), 1_250)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "0.99", currency: "USD", locale: us), 99)
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "", currency: "USD", locale: us))
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "1.234", currency: "USD", locale: us), "más de 2 decimales")
    }

    func testSanitizeAllowsOnlyTwoDecimalsAndOneSeparator() {
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("45.678", currency: "USD", locale: us), "45.67")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("1.2.3", currency: "USD", locale: us), "1.23")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput(".5", currency: "USD", locale: us), "0.5")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("007", currency: "USD", locale: us), "7")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("4,500", currency: "USD", locale: us), "4500", "la coma de miles se ignora")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("12,345", currency: "USD", locale: spain), "12,34")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("12.5", currency: "CLP", locale: us), "125", "CLP no usa decimales")
    }

    func testInputStringRoundTrips() {
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 450_000, currency: "USD", locale: us), "4500")
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 1_250, currency: "USD", locale: us), "12.50")
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 1_250, currency: "USD", locale: spain), "12,50")
        XCTAssertEqual(CurrencyFormatter.roundedToInputable(125_050, currency: "CLP", locale: us), 125_100)
        XCTAssertEqual(CurrencyFormatter.roundedToInputable(1_251, currency: "USD", locale: us), 1_251)
    }
}
