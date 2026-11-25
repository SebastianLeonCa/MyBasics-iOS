import XCTest
@testable import MyBasics

/// Reglas de los gastos compartidos:
/// - "Me debe": pagaste todo; cuando te pagan, tu gasto baja a tu parte.
/// - "Le debo": registras solo tu parte; al pagarla, el gasto no cambia.
final class SharedCostTests: XCTestCase {
    private typealias F = Fixtures

    private func dinner(owed: DebtDirection, settled: Bool) -> Expense {
        var e = F.expense(F.food, units: 22, at: F.date(2026, 10, 6))
        e.debts = [Debt(counterpartyName: "Roomie", amountCents: 1_100, direction: owed, isSettled: settled)]
        return e
    }

    func testTheyOweMeCountsFullAmountUntilPaidThenOnlyMyShare() {
        XCTAssertEqual(dinner(owed: .theyOweMe, settled: false).netAmountCents, 2_200, "aún no me pagan: pagué 22")
        let paid = dinner(owed: .theyOweMe, settled: true)
        XCTAssertEqual(paid.netAmountCents, 1_100, "ya me pagaron 11: mi gasto real es 11")
        XCTAssertEqual(paid.reimbursedCents, 1_100)
        XCTAssertEqual(paid.amountCents, 2_200, "se conserva cuánto pagué")
    }

    func testIOweThemNeverChangesTheExpense() {
        var mine = F.expense(F.food, units: 11, at: F.date(2026, 10, 6))
        mine.debts = [Debt(counterpartyName: "Roomie", amountCents: 1_100, direction: .iOweThem)]
        XCTAssertEqual(mine.netAmountCents, 1_100)
        mine.debts[0].isSettled = true
        XCTAssertEqual(mine.netAmountCents, 1_100, "pagar lo que debo no cambia el gasto")
    }

    func testTotalsAndChartUseNetAndDropZeroCategories() {
        var gift = F.expense(F.home, units: 30, at: F.date(2026, 10, 2))
        gift.debts = [Debt(counterpartyName: "Ana", amountCents: 3_000, direction: .theyOweMe, isSettled: true)]
        let expenses = [dinner(owed: .theyOweMe, settled: true), gift]

        XCTAssertEqual(ExpenseAnalytics.total(expenses), 1_100)
        let totals = ExpenseAnalytics.categoryTotals(expenses)
        XCTAssertEqual(totals.map(\.categoryId), [F.food.id], "Hogar quedó en $0: no aparece en el gráfico")
        XCTAssertEqual(totals.first?.amountCents, 1_100)
        XCTAssertEqual(ExpenseAnalytics.groupByDay(expenses).map(\.totalCents).reduce(0, +), 1_100)
    }

    @MainActor
    func testMarkingPaidInSharedLowersHomeTotal() async throws {
        let repo = MockExpenseRepository(expenses: [dinner(owed: .theyOweMe, settled: false)],
                                         categories: { [F.food] })
        let now = F.date(2026, 10, 14)
        let home = HomeViewModel(repository: repo, now: { now })
        await home.load()
        XCTAssertEqual(home.totalCents, 2_200)

        let shared = SharedViewModel(repository: repo)
        await shared.load()
        await shared.markPaid(try XCTUnwrap(shared.shares.first))

        await home.load()
        XCTAssertEqual(home.totalCents, 1_100)
    }
}

@MainActor
final class SharedFormTests: XCTestCase {
    private func makeViewModel() -> AddExpenseViewModel {
        AddExpenseViewModel(categoryRepository: MockCategoryRepository(categories: [Fixtures.food]), currency: "USD")
    }

    func testIOweThemUsesTheWholeAmountWithoutAskingAgain() throws {
        let vm = makeViewModel()
        vm.categoryId = Fixtures.food.id
        vm.setAmountText("11")
        vm.hasDebt = true
        vm.debtDirection = .iOweThem
        vm.debtPerson = "Roomie"

        XCTAssertTrue(vm.canSave, "no hace falta escribir otro monto")
        XCTAssertEqual(vm.debtAmountCents, 1_100)
        let expense = try XCTUnwrap(vm.makeExpense())
        XCTAssertEqual(expense.amountCents, 1_100)
        XCTAssertEqual(expense.debts.first?.amountCents, 1_100)
        XCTAssertEqual(expense.debts.first?.direction, .iOweThem)
    }

    func testTheyOweMeShowsWhatTheExpenseWillCostAfterBeingPaid() {
        let vm = makeViewModel()
        vm.setAmountText("22")
        vm.hasDebt = true
        XCTAssertEqual(vm.debtDirection, .theyOweMe)
        XCTAssertEqual(vm.debtAmountCents, 1_100, "por defecto, la mitad")
        XCTAssertEqual(vm.netAfterReimbursementCents, 1_100)

        vm.debtDirection = .iOweThem
        XCTAssertNil(vm.netAfterReimbursementCents)
    }
}
