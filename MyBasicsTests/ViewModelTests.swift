import XCTest
@testable import MyBasics

@MainActor
final class HomeViewModelTests: XCTestCase {
    private typealias F = Fixtures
    private let now = Fixtures.date(2026, 10, 14, 15)

    private func makeViewModel() -> (HomeViewModel, MockExpenseRepository) {
        let repo = MockExpenseRepository(
            expenses: [
                F.expense(F.home, pesos: 450_000, kind: .fixed, at: F.date(2026, 10, 1)),
                F.expense(F.food, pesos: 8_000, at: F.date(2026, 10, 12)),
                F.expense(F.food, pesos: 5_000, at: F.date(2026, 9, 20)),
            ],
            categories: { [F.home, F.food] }
        )
        let now = self.now
        return (HomeViewModel(repository: repo, now: { now }), repo)
    }

    func testLoadsOnlySelectedMonthAndAppliesFilter() async {
        let (vm, _) = makeViewModel()
        await vm.load()
        XCTAssertEqual(vm.expenses.count, 2)
        XCTAssertEqual(vm.totalCents, 45_800_000)

        vm.filter = .variable
        XCTAssertEqual(vm.totalCents, 800_000)

        vm.showPreviousMonth()
        await vm.load()
        XCTAssertEqual(vm.monthTitle, "Septiembre 2026")
        XCTAssertEqual(vm.totalCents, 500_000)
        XCTAssertTrue(vm.canGoToNextMonth)
    }

    func testCannotGoPastCurrentMonth() {
        let (vm, _) = makeViewModel()
        XCTAssertFalse(vm.canGoToNextMonth)
        vm.showNextMonth()
        XCTAssertEqual(vm.monthTitle, "Octubre 2026")
    }

    func testSelectionTogglesAndClearsOnFilterChange() async {
        let (vm, _) = makeViewModel()
        await vm.load()
        vm.toggleSelection(F.food.id)
        XCTAssertEqual(vm.selectedTotal?.name, "Comida")
        vm.toggleSelection(F.food.id)
        XCTAssertNil(vm.selectedTotal)

        vm.toggleSelection(F.home.id)
        vm.filter = .fixed
        XCTAssertNil(vm.selectedCategoryId)
    }

    func testDidSaveAndDeleteUpdateImmediately() async throws {
        let (vm, repo) = makeViewModel()
        await vm.load()

        let created = try await repo.create(F.expense(F.food, pesos: 3_000, at: F.date(2026, 10, 13)))
        vm.didSave(created)
        XCTAssertEqual(vm.expenses.count, 3)

        var edited = created
        edited.spentAt = F.date(2026, 9, 1)   // movido a otro mes → desaparece de este
        vm.didSave(edited)
        XCTAssertEqual(vm.expenses.count, 2)

        let toDelete = try XCTUnwrap(vm.expenses.first)
        await vm.delete(toDelete)
        XCTAssertEqual(vm.expenses.count, 1)
        let stored = try await repo.fetchExpenses(in: now.monthInterval())
        XCTAssertFalse(stored.contains { $0.id == toDelete.id })
    }
}

@MainActor
final class AddExpenseViewModelTests: XCTestCase {
    private typealias F = Fixtures

    private func makeViewModel(editing: Expense? = nil) -> AddExpenseViewModel {
        AddExpenseViewModel(
            editing: editing,
            expenseRepository: MockExpenseRepository(categories: { [F.food] }),
            categoryRepository: MockCategoryRepository(categories: [F.food]),
            currency: "CLP"
        )
    }

    func testCannotSaveWithoutAmountOrCategory() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.canSave)
        vm.amountText = "2500"
        XCTAssertFalse(vm.canSave)
        vm.categoryId = F.food.id
        XCTAssertTrue(vm.canSave)
        vm.amountText = "0"
        XCTAssertFalse(vm.canSave)
    }

    func testDebtDefaultsToHalfUntilEdited() {
        let vm = makeViewModel()
        vm.amountText = "5000"
        vm.hasDebt = true
        XCTAssertEqual(vm.debtAmountCents, 250_000)

        vm.amountText = "3001"   // la mitad se redondea a pesos enteros
        XCTAssertEqual(vm.debtAmountCents, 150_100)

        vm.setDebtAmountText("1000")
        vm.amountText = "9000"
        XCTAssertEqual(vm.debtAmountCents, 100_000)
    }

    func testDebtValidation() {
        let vm = makeViewModel()
        vm.amountText = "5000"
        vm.categoryId = F.food.id
        vm.hasDebt = true
        XCTAssertFalse(vm.canSave, "falta la persona")
        vm.debtPerson = "Juan"
        XCTAssertTrue(vm.canSave)
        vm.setDebtAmountText("6000")
        XCTAssertFalse(vm.canSave, "la deuda no puede superar el gasto")
    }

    func testEditingPreloadsAndKeepsIds() async throws {
        var original = F.expense(F.food, pesos: 4_000, at: F.date(2026, 10, 10), note: "Pizza")
        original.debts = [Debt(counterpartyName: "Ana", amountCents: 200_000, direction: .iOweThem)]
        let vm = makeViewModel(editing: original)

        XCTAssertEqual(vm.title, "Editar gasto")
        XCTAssertEqual(vm.amountText, "4000")
        XCTAssertEqual(vm.debtPerson, "Ana")
        XCTAssertEqual(vm.debtDirection, .iOweThem)

        vm.amountText = "4500"
        let edited = try XCTUnwrap(vm.makeExpense())
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.debts.first?.id, original.debts.first?.id)
        XCTAssertEqual(edited.debts.first?.amountCents, 200_000, "la deuda editada no se recalcula")
        XCTAssertEqual(edited.amountCents, 450_000)
    }
}

@MainActor
final class DebtsAndMockDataTests: XCTestCase {
    func testMockDataIsRealistic() {
        let now = Fixtures.date(2026, 10, 14, 15)
        let expenses = MockData.expenses(categories: MyBasics.Category.defaults, now: now)

        XCTAssertEqual(expenses.count, 40)
        XCTAssertEqual(Set(expenses.map { $0.spentAt.startOfMonth() }).count, 3)
        XCTAssertTrue(expenses.allSatisfy { $0.spentAt <= now && $0.amountCents > 0 })
        XCTAssertGreaterThan(expenses.filter(\.hasPendingDebt).count, 2)
    }

    func testSettleDebtRemovesItAndUpdatesTotals() async throws {
        let now = Fixtures.date(2026, 10, 14, 15)
        let repo = MockExpenseRepository(expenses: MockData.expenses(categories: MyBasics.Category.defaults, now: now))
        let vm = DebtsViewModel(repository: repo)
        await vm.load()
        let before = vm.items.count
        let item = try XCTUnwrap(vm.items.first { $0.debt.direction == .theyOweMe })
        let owedBefore = vm.theyOweMeCents

        await vm.settle(item)

        XCTAssertEqual(vm.items.count, before - 1)
        XCTAssertEqual(vm.theyOweMeCents, owedBefore - item.debt.amountCents)
        await vm.load()
        XCTAssertFalse(vm.items.contains { $0.id == item.id }, "persistido en el repositorio")
    }
}
