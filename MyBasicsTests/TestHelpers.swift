import Foundation
@testable import MyBasics

nonisolated enum Fixtures {
    static let calendar = Calendar.app

    static let food = MyBasics.Category(name: "Comida", colorHex: "#FF6B35", icon: "fork.knife", isDefault: true)
    static let home = MyBasics.Category(name: "Hogar", colorHex: "#8338EC", icon: "house", isDefault: true)
    static let transport = MyBasics.Category(name: "Transporte", colorHex: "#3A86FF", icon: "car", isDefault: true)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func expense(
        _ category: MyBasics.Category, units: Int, kind: ExpenseKind = .variable, at date: Date, note: String? = nil
    ) -> Expense {
        Expense(categoryId: category.id, amountCents: units * 100, kind: kind, note: note,
                spentAt: date, category: category)
    }
}

/// Repositorio que falla a pedido, para probar rollback y reintento.
final class FlakyExpenseRepository: ExpenseRepository {
    private let inner: MockExpenseRepository
    var failReads = false
    var failWrites = false

    init(expenses: [Expense]) {
        inner = MockExpenseRepository(expenses: expenses, categories: { [Fixtures.food, Fixtures.home, Fixtures.transport] })
    }

    private func check(_ fail: Bool) throws {
        if fail { throw URLError(.notConnectedToInternet) }
    }

    func fetchExpenses(in interval: DateInterval) async throws -> [Expense] {
        try check(failReads); return try await inner.fetchExpenses(in: interval)
    }
    func fetchExpensesWithPendingDebts() async throws -> [Expense] {
        try check(failReads); return try await inner.fetchExpensesWithPendingDebts()
    }
    func create(_ expense: Expense) async throws -> Expense {
        try check(failWrites); return try await inner.create(expense)
    }
    func update(_ expense: Expense) async throws -> Expense {
        try check(failWrites); return try await inner.update(expense)
    }
    func delete(id: UUID) async throws {
        try check(failWrites); try await inner.delete(id: id)
    }
    func settleDebt(id: UUID) async throws {
        try check(failWrites); try await inner.settleDebt(id: id)
    }
}
