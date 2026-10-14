import Foundation

/// Acceso a gastos (y sus deudas). Implementaciones: Mock (memoria) y Supabase (Fase 2).
protocol ExpenseRepository: AnyObject {
    /// Gastos con `spentAt` dentro del intervalo [start, end), con categoría y deudas embebidas.
    func fetchExpenses(in interval: DateInterval) async throws -> [Expense]
    /// Crea el gasto junto con sus deudas (una operación lógica).
    func create(_ expense: Expense) async throws -> Expense
    func update(_ expense: Expense) async throws -> Expense
    func delete(id: UUID) async throws
}
