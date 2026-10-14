import SwiftUI

/// Una deuda pendiente junto al gasto que la originó.
struct PendingDebtItem: Identifiable, Hashable {
    var id: UUID { debt.id }
    let debt: Debt
    let expense: Expense
}

@Observable
final class DebtsViewModel {
    private let repository: any ExpenseRepository

    private(set) var items: [PendingDebtItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(repository: any ExpenseRepository) {
        self.repository = repository
    }

    var theyOweMeCents: Int { total(.theyOweMe) }
    var iOweThemCents: Int { total(.iOweThem) }

    private func total(_ direction: DebtDirection) -> Int {
        items.filter { $0.debt.direction == direction }.reduce(0) { $0 + $1.debt.amountCents }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let expenses = try await repository.fetchExpensesWithPendingDebts()
            items = expenses.flatMap { expense in
                expense.debts.filter { !$0.isSettled }.map { PendingDebtItem(debt: $0, expense: expense) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Marca como saldada; se quita de la lista al instante y se revierte si falla.
    func settle(_ item: PendingDebtItem) async {
        let snapshot = items
        withAnimation(.smooth) { items.removeAll { $0.id == item.id } }
        do {
            try await repository.settleDebt(id: item.debt.id)
        } catch {
            withAnimation(.smooth) { items = snapshot }
            errorMessage = "No se pudo marcar como saldada. \(error.localizedDescription)"
        }
    }
}
