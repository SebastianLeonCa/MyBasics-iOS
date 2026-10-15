import XCTest
@testable import MyBasics

/// El formateador con CLP, USD y PEN. Los montos se guardan siempre ×100: cambiar de moneda
/// nunca altera la magnitud (5000 se ve "5.000"/"5,000", jamás "50,00").
@MainActor
final class CurrencyFormatterTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let chile = Locale(identifier: "es_CL")
    private let peru = Locale(identifier: "es_PE")
    private let spain = Locale(identifier: "es_ES")

    // MARK: Mostrar

    func testCLPHasNoDecimals() {
        XCTAssertEqual(CurrencyFormatter.fractionDigits(for: "CLP"), 0)
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "CLP", locale: chile), "$5.000")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "CLP", locale: us), "$5,000")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 0, currency: "CLP", locale: chile), "$0")
    }

    func testUSDHasTwoDecimals() {
        XCTAssertEqual(CurrencyFormatter.fractionDigits(for: "USD"), 2)
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "USD", locale: us), "$5,000.00")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 1_250, currency: "USD", locale: us), "$12.50")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "USD", locale: chile), "$5.000,00")
    }

    func testPENUsesSolSymbolInAnyLanguage() {
        XCTAssertEqual(CurrencyFormatter.fractionDigits(for: "PEN"), 2)
        XCTAssertEqual(CurrencyFormatter.symbol(for: "PEN"), "S/")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "PEN", locale: peru), "S/ 5,000.00")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "PEN", locale: us), "S/ 5,000.00",
                       "no 'PEN 5,000.00' aunque el iPhone esté en inglés")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 10_000, currency: "PEN", locale: us), "S/ 100.00")
    }

    func testChangingCurrencyKeepsTheMagnitude() {
        // El mismo número guardado, mostrado en las tres monedas.
        let stored = 500_000
        XCTAssertEqual(CurrencyFormatter.string(fromCents: stored, currency: "CLP", locale: chile), "$5.000")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: stored, currency: "USD", locale: chile), "$5.000,00")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: stored, currency: "PEN", locale: chile), "S/ 5.000,00")
        XCTAssertNotEqual(CurrencyFormatter.string(fromCents: stored, currency: "CLP", locale: chile), "$50,00")
    }

    func testCentsShownInCLPAreRoundedOnlyOnScreen() {
        // $12,50 guardados (de cuando la moneda era USD) se ven como $13 en CLP.
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 1_250, currency: "CLP", locale: chile), "$13")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 1_249, currency: "CLP", locale: chile), "$12")
    }

    func testNegativeAndSpainLayout() {
        XCTAssertEqual(CurrencyFormatter.string(fromCents: -1_250, currency: "USD", locale: us), "-$12.50")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: "USD", locale: spain), "$5000,00")
    }

    // MARK: Escribir

    func testTypingAmountsInEachCurrency() {
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "5000", currency: "CLP", locale: chile), 500_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "5000", currency: "USD", locale: us), 500_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "5000", currency: "PEN", locale: peru), 500_000)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "12.5", currency: "PEN", locale: peru), 1_250)
        XCTAssertEqual(CurrencyFormatter.cents(fromInput: "12,5", currency: "USD", locale: chile), 1_250)
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "12.5", currency: "CLP", locale: us), "CLP no acepta decimales")
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "1.234", currency: "USD", locale: us), "más de 2 decimales")
        XCTAssertNil(CurrencyFormatter.cents(fromInput: "", currency: "USD", locale: us))
    }

    func testSanitizeRespectsEachCurrency() {
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("45.678", currency: "USD", locale: us), "45.67")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("45.678", currency: "PEN", locale: us), "45.67")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("12.5", currency: "CLP", locale: us), "125", "CLP descarta el separador")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("1.2.3", currency: "USD", locale: us), "1.23")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput(".5", currency: "USD", locale: us), "0.5")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("007", currency: "PEN", locale: us), "7")
        XCTAssertEqual(CurrencyFormatter.sanitizeInput("4,500", currency: "USD", locale: us), "4500", "la coma de miles se ignora")
    }

    func testInputStringRoundTrips() {
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 500_000, currency: "CLP"), "5000")
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 1_250, currency: "USD", locale: us), "12.50")
        XCTAssertEqual(CurrencyFormatter.inputString(fromCents: 1_250, currency: "PEN", locale: chile), "12,50")
        XCTAssertEqual(CurrencyFormatter.roundedToInputable(125_050, currency: "CLP"), 125_100)
        XCTAssertEqual(CurrencyFormatter.roundedToInputable(1_251, currency: "PEN"), 1_251)
    }
}

/// La moneda de la app es fija (USD); el formateador sigue soportando otras.
@MainActor
final class CurrencyTests: XCTestCase {
    func testAppCurrencyIsFixedUSD() {
        XCTAssertEqual(AppEnvironment.mock().currency, "USD")
        XCTAssertEqual(CurrencyFormatter.string(fromCents: 500_000, currency: AppEnvironment.mock().currency,
                                                locale: Locale(identifier: "en_US")), "$5,000.00")
    }

    func testEditingInCLPKeepsStoredCentsIfAmountUntouched() throws {
        let expense = Fixtures.expense(Fixtures.food, units: 0, at: Fixtures.date(2026, 10, 1))
        var withCents = expense
        withCents.amountCents = 1_250   // $12,50 guardados antes, con USD
        let vm = AddExpenseViewModel(
            editing: withCents, categoryRepository: MockCategoryRepository(categories: [Fixtures.food]), currency: "CLP")
        XCTAssertEqual(vm.amountText, "12")
        XCTAssertEqual(try XCTUnwrap(vm.makeExpense()).amountCents, 1_250, "no se pierden los centésimos por solo abrirlo")
        vm.setAmountText("15")
        XCTAssertEqual(try XCTUnwrap(vm.makeExpense()).amountCents, 1_500)
    }
}
