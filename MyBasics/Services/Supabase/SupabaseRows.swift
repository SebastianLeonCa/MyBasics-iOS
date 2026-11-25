import Foundation

/// Columnas y cuerpos de las peticiones a Supabase, en un solo lugar.
nonisolated enum SupabaseQuery {
    static let categoryColumns = "id,name,color_hex,icon,is_default"
    static let debtColumns = "id,counterparty_name,amount_cents,direction,is_settled,settled_at"

    /// Gasto con su categoría y sus montos compartidos embebidos (una sola consulta).
    static let expenseColumns =
        "id,category_id,amount_cents,kind,note,spent_at,category:categories(\(categoryColumns)),debts(\(debtColumns))"

    /// Igual, pero solo gastos con al menos un compartido pendiente (`!inner` filtra los padres).
    static let expenseWithPendingDebtsColumns =
        "id,category_id,amount_cents,kind,note,spent_at,category:categories(\(categoryColumns)),debts!inner(\(debtColumns))"
}

/// Parámetros de la función `save_expense` (ver supabase/schema.sql).
nonisolated struct SaveExpenseParams: Encodable, Sendable {
    let p_expense: ExpensePayload
    let p_debts: [DebtPayload]

    init(_ expense: Expense) {
        p_expense = ExpensePayload(expense)
        p_debts = expense.debts.map(DebtPayload.init)
    }
}

nonisolated struct ExpensePayload: Encodable, Sendable {
    let id: UUID
    let category_id: UUID
    let amount_cents: Int
    let kind: String
    let note: String?
    let spent_at: String

    init(_ e: Expense) {
        id = e.id
        category_id = e.categoryId
        amount_cents = e.amountCents
        kind = e.kind.rawValue
        note = e.note
        spent_at = JSONCoding.iso8601String(e.spentAt)
    }
}

nonisolated struct DebtPayload: Encodable, Sendable {
    let id: UUID
    let counterparty_name: String
    let amount_cents: Int
    let direction: String
    let is_settled: Bool
    let settled_at: String?

    init(_ d: Debt) {
        id = d.id
        counterparty_name = d.counterpartyName
        amount_cents = d.amountCents
        direction = d.direction.rawValue
        is_settled = d.isSettled
        settled_at = d.settledAt.map(JSONCoding.iso8601String)
    }
}

nonisolated struct CategoryInsert: Encodable, Sendable {
    let id: UUID
    let name: String
    let color_hex: String
    let icon: String
    let is_default: Bool

    init(_ c: Category) {
        id = c.id
        name = c.name
        color_hex = c.colorHex
        icon = c.icon
        is_default = false   // las por defecto solo las crea el servidor
    }
}

nonisolated struct SettleDebtPayload: Encodable, Sendable {
    let is_settled = true
    let settled_at: String
}

/// Para leer solo el id de las filas afectadas.
nonisolated struct IDRow: Decodable, Sendable {
    let id: UUID
}
