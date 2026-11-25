import Foundation

/// Repositorio en memoria. Se pierde al cerrar la app.
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

    func fetchExpensesWithPendingDebts() async throws -> [Expense] {
        expenses
            .filter(\.hasPendingDebt)
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

    func settleDebt(id: UUID) async throws {
        for e in expenses.indices {
            if let d = expenses[e].debts.firstIndex(where: { $0.id == id }) {
                expenses[e].debts[d].isSettled = true
                expenses[e].debts[d].settledAt = .now
                return
            }
        }
        throw RepositoryError.notFound
    }

    /// Simula el join `category:categories(...)` de Supabase.
    private func withCategory(_ expense: Expense) -> Expense {
        var copy = expense
        copy.category = categories().first { $0.id == expense.categoryId }
        return copy
    }
}
