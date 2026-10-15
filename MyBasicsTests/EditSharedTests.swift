import XCTest
@testable import MyBasics

@MainActor
final class EditSharedTests: XCTestCase {
    /// Caso reportado: pagué 22, me deben 11; edito el gasto a 18.
    private func editDinner(settled: Bool) throws -> (AddExpenseViewModel, Expense) {
        var dinner = Fixtures.expense(Fixtures.food, units: 22, at: Fixtures.date(2026, 10, 6))
        dinner.debts = [Debt(counterpartyName: "Roomie", amountCents: 1_100, direction: .theyOweMe, isSettled: settled)]
        let vm = AddExpenseViewModel(
            editing: dinner,
            categoryRepository: MockCategoryRepository(categories: [Fixtures.food]),
            currency: "USD")
        vm.setAmountText("1")
        vm.setAmountText("18")
        return (vm, try XCTUnwrap(vm.makeExpense()))
    }

    func testEditingTheTotalNeverChangesWhatTheyOweMe() throws {
        for settled in [false, true] {
            let (vm, edited) = try editDinner(settled: settled)
            XCTAssertEqual(edited.debts[0].amountCents, 1_100, "me siguen debiendo 11 (pagado: \(settled))")
            XCTAssertEqual(edited.debts[0].isSettled, settled)
            XCTAssertEqual(edited.amountCents, 1_800)
            XCTAssertEqual(vm.netAfterReimbursementCents, 700, "tu parte: 18 − 11")
            XCTAssertEqual(vm.isDebtSettled, settled)
            XCTAssertEqual(edited.netAmountCents, settled ? 700 : 1_800)
        }
    }

    func testSuggestionFollowsTotalOnlyUntilYouTypeAnAmount() {
        let vm = AddExpenseViewModel(categoryRepository: MockCategoryRepository(), currency: "USD")
        vm.hasDebt = true
        vm.setAmountText("22")
        XCTAssertTrue(vm.isUsingSuggestedDebt)
        XCTAssertEqual(vm.debtAmountCents, 1_100, "sugerencia: la mitad")
        vm.setDebtAmountText("11")
        vm.setAmountText("18")
        XCTAssertFalse(vm.isUsingSuggestedDebt)
        XCTAssertEqual(vm.debtAmountCents, 1_100, "lo que escribiste no cambia con el total")
    }
}
