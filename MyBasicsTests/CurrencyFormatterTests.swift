import XCTest
@testable import MyBasics

@MainActor
final class CurrencyFormatterTests: XCTestCase {
    func testFormatsCLPWithoutDecimals() {
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 250_000, currency: "CLP"), "$2.500")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 0, currency: "CLP"), "$0")
    }

    func testParsesUserInputToCents() {
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "2500", currency: "CLP"), 250_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "2.500", currency: "CLP"), 250_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "12,5", currency: "USD"), 1_250)
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "", currency: "CLP"))
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "1,234", currency: "USD"))
    }

    func testInputStringRoundTrips() {
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 125_000, currency: "CLP"), "1250")
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 1_250, currency: "USD"), "12,50")
        XCTAssertEqual(CurrencyFormatter.roundedToDisplayable(125_050, currency: "CLP"), 125_100)
    }
}
