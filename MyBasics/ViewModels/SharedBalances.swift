import Foundation

/// Un monto pendiente de un gasto compartido, junto al gasto que lo originó.
nonisolated struct PendingShare: Identifiable, Hashable, Sendable {
    var id: UUID { debt.id }
    let debt: Debt
    let expense: Expense

    /// Positivo si la persona me debe, negativo si yo le debo.
    var signedCents: Int { debt.direction == .theyOweMe ? debt.amountCents : -debt.amountCents }
}

/// Saldo neto con una persona.
nonisolated struct PersonBalance: Identifiable, Hashable, Sendable {
    var id: String { key }
    let key: String
    let name: String
    let items: [PendingShare]
    /// Positivo: la persona me debe. Negativo: yo le debo.
    var netCents: Int { items.reduce(0) { $0 + $1.signedCents } }
}

nonisolated enum SharedBalances {
    static func pendingShares(from expenses: [Expense]) -> [PendingShare] {
        expenses.flatMap { expense in
            expense.debts.filter { !$0.isSettled }.map { PendingShare(debt: $0, expense: expense) }
        }
    }

    /// Agrupa por persona (sin distinguir mayúsculas), mayor saldo absoluto primero.
    static func balances(from shares: [PendingShare]) -> [PersonBalance] {
        Dictionary(grouping: shares) { $0.debt.counterpartyName.trimmingCharacters(in: .whitespaces).lowercased() }
            .map { key, items in
                PersonBalance(
                    key: key,
                    name: items.first?.debt.counterpartyName.trimmingCharacters(in: .whitespaces) ?? key,
                    items: items.sorted { $0.expense.spentAt > $1.expense.spentAt }
                )
            }
            .sorted { abs($0.netCents) != abs($1.netCents) ? abs($0.netCents) > abs($1.netCents) : $0.name < $1.name }
    }

    static func total(_ shares: [PendingShare], direction: DebtDirection) -> Int {
        shares.filter { $0.debt.direction == direction }.reduce(0) { $0 + $1.debt.amountCents }
    }
}
