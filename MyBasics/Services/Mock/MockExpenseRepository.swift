import Foundation

/// Repositorio en memoria. Se pierde al cerrar la app (los datos de ejemplo llegan en la Fase 1).
final class MockExpenseRepository: ExpenseRepository {
    private var expenses: [Expense]
    private let categories: () -> [Category]

    init(expenses: [Expense] = [], categories: @escaping () -> [Category] = { Category.defaults }) {
        self.expenses = expenses
        self.categories = categories
    }

    func fetchExpenses(in interval: DateInterval) async throws -> [Expense] {
        expenses
            .filter { $0.spentAt >= interval.start && $0.spentAt < interval.end }
            .map(withCategory)
            .sorted { $0.spentAt > $1.spentAt }
    }

    func create(_ expense: Expense) async throws -> Expense {
        let stored = withCategory(expense)
        expenses.append(stored)
        return stored
    }

    func update(_ expense: Expense) async throws -> Expense {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else {
            throw RepositoryError.notFound
        }
        let stored = withCategory(expense)
        expenses[index] = stored
        return stored
    }

    func delete(id: UUID) async throws {
        expenses.removeAll { $0.id == id }
    }

    /// Simula el join `category:categories(...)` de Supabase.
    private func withCategory(_ expense: Expense) -> Expense {
        var copy = expense
        copy.category = categories().first { $0.id == expense.categoryId }
        return copy
    }
}
