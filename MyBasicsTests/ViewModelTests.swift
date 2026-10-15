import XCTest
@testable import MyBasics

@MainActor
final class HomeViewModelTests: XCTestCase {
    private typealias F = Fixtures
    private let now = Fixtures.date(2026, 10, 14, 15)

    private func makeViewModel() -> (HomeViewModel, MockExpenseRepository) {
        let repo = MockExpenseRepository(
            expenses: [
                F.expense(F.home, units: 450_000, kind: .fixed, at: F.date(2026, 10, 1)),
                F.expense(F.food, units: 8_000, at: F.date(2026, 10, 12)),
                F.expense(F.food, units: 5_000, at: F.date(2026, 9, 20)),
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
        XCTAssertEqual(vm.month, F.date(2026, 9, 1, 0))
        XCTAssertEqual(vm.totalCents, 500_000)
        XCTAssertTrue(vm.canGoToNextMonth)
    }

    func testCannotGoPastCurrentMonth() {
        let (vm, _) = makeViewModel()
        XCTAssertFalse(vm.canGoToNextMonth)
        vm.showNextMonth()
        XCTAssertEqual(vm.month, F.date(2026, 10, 1, 0))
    }

    func testSelectionTogglesAndClearsOnFilterChange() async {
        let (vm, _) = makeViewModel()
        await vm.load()
        vm.toggleSelection(F.food.id)
        XCTAssertEqual(vm.selectedTotal?.categoryId, F.food.id)
        vm.toggleSelection(F.food.id)
        XCTAssertNil(vm.selectedTotal)

        vm.toggleSelection(F.home.id)
        vm.filter = .fixed
        XCTAssertNil(vm.selectedCategoryId)
    }

    func testSaveAndDeletePersistAndUpdateImmediately() async throws {
        let (vm, repo) = makeViewModel()
        await vm.load()

        let created = F.expense(F.food, units: 3_000, at: F.date(2026, 10, 13))
        await vm.save(created, isNew: true)
        XCTAssertEqual(vm.expenses.count, 3)

        var edited = created
        edited.spentAt = F.date(2026, 9, 1)   // movido a otro mes → desaparece de este
        await vm.save(edited, isNew: false)
        XCTAssertEqual(vm.expenses.count, 2)
        let september = try await repo.fetchExpenses(in: F.date(2026, 9, 1).monthInterval())
        XCTAssertTrue(september.contains { $0.id == created.id }, "el repositorio tiene la edición")

        let toDelete = try XCTUnwrap(vm.expenses.first)
        await vm.delete(toDelete)
        XCTAssertEqual(vm.expenses.count, 1)
        let stored = try await repo.fetchExpenses(in: now.monthInterval())
        XCTAssertFalse(stored.contains { $0.id == toDelete.id })
        XCTAssertNil(vm.alert)
    }

    func testOptimisticSaveRollsBackAndOffersRetry() async throws {
        let repo = FlakyExpenseRepository(expenses: [F.expense(F.food, units: 10, at: F.date(2026, 10, 2))])
        let now = self.now
        let vm = HomeViewModel(repository: repo, now: { now })
        await vm.load()
        let original = try XCTUnwrap(vm.expenses.first)

        repo.failWrites = true
        var edited = original
        edited.amountCents = 99_900
        await vm.save(edited, isNew: false)
        XCTAssertEqual(vm.expenses.map(\.amountCents), [original.amountCents], "rollback a la versión anterior")
        XCTAssertNotNil(vm.alert?.retry)

        await vm.save(F.expense(F.food, units: 5, at: F.date(2026, 10, 3)), isNew: true)
        XCTAssertEqual(vm.expenses.count, 1, "el gasto nuevo se quita si falla")

        await vm.delete(original)
        XCTAssertEqual(vm.expenses.count, 1, "el gasto eliminado vuelve si falla")

        repo.failWrites = false
        await vm.alert?.retry?()
        XCTAssertEqual(vm.expenses.count, 0, "Reintentar repite la última acción (eliminar)")
    }

    func testFirstLoadErrorShowsErrorStateAndRetryRecovers() async {
        let repo = FlakyExpenseRepository(expenses: [F.expense(F.food, units: 10, at: F.date(2026, 10, 2))])
        repo.failReads = true
        let now = self.now
        let vm = HomeViewModel(repository: repo, now: { now })

        XCTAssertTrue(vm.isShowingSkeleton)
        await vm.load()
        XCTAssertNotNil(vm.loadError)
        XCTAssertFalse(vm.isShowingSkeleton)

        repo.failReads = false
        await vm.load()
        XCTAssertNil(vm.loadError)
        XCTAssertEqual(vm.expenses.count, 1)
    }

    func testChangingMonthClearsOldDataUntilLoaded() async {
        let (vm, _) = makeViewModel()
        await vm.load()
        vm.showPreviousMonth()
        XCTAssertTrue(vm.expenses.isEmpty)
        XCTAssertTrue(vm.isShowingSkeleton)
    }
}

@MainActor
final class AddExpenseViewModelTests: XCTestCase {
    private typealias F = Fixtures

    private func makeViewModel(editing: Expense? = nil) -> AddExpenseViewModel {
        AddExpenseViewModel(
            editing: editing,
            categoryRepository: MockCategoryRepository(categories: [F.food]),
            currency: "USD"
        )
    }

    func testCannotSaveWithoutAmountOrCategory() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.canSave)
        vm.setAmountText("2500")
        XCTAssertFalse(vm.canSave)
        vm.categoryId = F.food.id
        XCTAssertTrue(vm.canSave)
        vm.setAmountText("0")
        XCTAssertFalse(vm.canSave)
    }

    func testDebtDefaultsToHalfUntilEdited() {
        let vm = makeViewModel()
        vm.setAmountText("5000")
        vm.hasDebt = true
        XCTAssertEqual(vm.debtAmountCents, 250_000)

        vm.setAmountText("3001")   // la mitad exacta en centavos: 1500.50
        XCTAssertEqual(vm.debtAmountCents, 150_050)

        vm.setDebtAmountText("1000")
        vm.setAmountText("9000")
        XCTAssertEqual(vm.debtAmountCents, 100_000)
    }

    func testDebtValidation() {
        let vm = makeViewModel()
        vm.setAmountText("5000")
        vm.categoryId = F.food.id
        vm.hasDebt = true
        XCTAssertFalse(vm.canSave, "falta la persona")
        vm.debtPerson = "Juan"
        XCTAssertTrue(vm.canSave)
        vm.setDebtAmountText("6000")
        XCTAssertFalse(vm.canSave, "la deuda no puede superar el gasto")
    }

    func testEditingPreloadsAndKeepsIds() async throws {
        var original = F.expense(F.food, units: 4_000, at: F.date(2026, 10, 10), note: "Pizza")
        original.debts = [Debt(counterpartyName: "Ana", amountCents: 200_000, direction: .theyOweMe)]
        let vm = makeViewModel(editing: original)

        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.amountText, "4000")
        XCTAssertEqual(vm.debtPerson, "Ana")
        XCTAssertEqual(vm.debtDirection, .theyOweMe)

        vm.setAmountText("4500")
        let edited = try XCTUnwrap(vm.makeExpense())
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.debts.first?.id, original.debts.first?.id)
        XCTAssertEqual(edited.debts.first?.amountCents, 200_000, "la deuda editada no se recalcula")
        XCTAssertEqual(edited.amountCents, 450_000)

        // Con "Le debo", lo que debo es siempre el gasto completo (mi parte).
        vm.debtDirection = .iOweThem
        XCTAssertEqual(try XCTUnwrap(vm.makeExpense()).debts.first?.amountCents, 450_000)
    }
}

@MainActor
final class AmountInputTests: XCTestCase {
    func testAmountFieldKeepsAtMostTwoDecimals() {
        let vm = AddExpenseViewModel(
            categoryRepository: MockCategoryRepository(),
            currency: "USD")
        let sep = CurrencyFormatter.decimalSeparator()
        vm.setAmountText("12\(sep)345")
        XCTAssertEqual(vm.amountText, "12\(sep)34")
        XCTAssertEqual(vm.amountCents, 1_234)
    }

    func testChoosingSubscriptionsMakesExpenseFixed() async {
        let vm = AddExpenseViewModel(
            categoryRepository: MockCategoryRepository(),
            currency: "USD")
        await vm.loadCategories()
        XCTAssertEqual(vm.kind, .variable)
        vm.categoryId = vm.categories.first(where: \.isSubscriptions)?.id
        XCTAssertEqual(vm.kind, .fixed)
    }
}

@MainActor
final class MockDataTests: XCTestCase {
    func testMockDataIsRealistic() {
        let now = Fixtures.date(2026, 10, 14, 15)
        let expenses = MockData.expenses(categories: MyBasics.Category.defaults, now: now)

        XCTAssertTrue((38...45).contains(expenses.count), "~40 gastos, hay \(expenses.count)")
        XCTAssertEqual(Set(expenses.map { $0.spentAt.startOfMonth() }).count, 3)
        XCTAssertTrue(expenses.allSatisfy { $0.spentAt <= now && $0.amountCents > 0 && $0.currency == "USD" })
        XCTAssertGreaterThan(expenses.filter(\.hasPendingDebt).count, 2)
    }
}
