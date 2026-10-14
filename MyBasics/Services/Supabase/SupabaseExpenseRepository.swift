import Foundation
import Supabase

final class SupabaseExpenseRepository: ExpenseRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchExpenses(in interval: DateInterval) async throws -> [Expense] {
        try await client
            .from("expenses")
            .select(SupabaseQuery.expenseColumns)
            .gte("spent_at", value: interval.start)
            .lt("spent_at", value: interval.end)
            .order("spent_at", ascending: false)
            .execute()
            .value
    }

    func fetchExpensesWithPendingDebts() async throws -> [Expense] {
        try await client
            .from("expenses")
            .select(SupabaseQuery.expenseWithPendingDebtsColumns)
            .eq("debts.is_settled", value: false)
            .order("spent_at", ascending: false)
            .execute()
            .value
    }

    func create(_ expense: Expense) async throws -> Expense {
        try await save(expense)
    }

    func update(_ expense: Expense) async throws -> Expense {
        try await save(expense)
    }

    func delete(id: UUID) async throws {
        // Los compartidos se borran solos (ON DELETE CASCADE).
        let deleted: [IDRow] = try await client
            .from("expenses")
            .delete()
            .eq("id", value: id)
            .select("id")
            .execute()
            .value
        if deleted.isEmpty { throw RepositoryError.notFound }
    }

    func settleDebt(id: UUID) async throws {
        let updated: [IDRow] = try await client
            .from("debts")
            .update(SettleDebtPayload(settled_at: JSONCoding.iso8601String(.now)))
            .eq("id", value: id)
            .select("id")
            .execute()
            .value
        if updated.isEmpty { throw RepositoryError.notFound }
    }

    /// Gasto + compartidos en una sola transacción (función `save_expense`), y luego
    /// se lee de vuelta con la categoría embebida para devolver exactamente lo guardado.
    private func save(_ expense: Expense) async throws -> Expense {
        try await client
            .rpc("save_expense", params: SaveExpenseParams(expense))
            .execute()

        return try await client
            .from("expenses")
            .select(SupabaseQuery.expenseColumns)
            .eq("id", value: expense.id)
            .single()
            .execute()
            .value
    }
}
