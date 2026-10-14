import SwiftUI

/// Pantalla "Compartidos": quién me debe y a quién le debo, por gastos compartidos.
@Observable
final class SharedViewModel {
    private let repository: any ExpenseRepository

    private(set) var shares: [PendingShare] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(repository: any ExpenseRepository) {
        self.repository = repository
    }

    var balances: [PersonBalance] { SharedBalances.balances(from: shares) }
    var owedToMeCents: Int { SharedBalances.total(shares, direction: .theyOweMe) }
    var iOweCents: Int { SharedBalances.total(shares, direction: .iOweThem) }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            shares = SharedBalances.pendingShares(from: try await repository.fetchExpensesWithPendingDebts())
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Marca como pagado; se quita de la lista al instante y se revierte si falla.
    func markPaid(_ share: PendingShare) async {
        let snapshot = shares
        withAnimation(.smooth) { shares.removeAll { $0.id == share.id } }
        do {
            try await repository.settleDebt(id: share.debt.id)
        } catch {
            withAnimation(.smooth) { shares = snapshot }
            errorMessage = String(localized: "No se pudo marcar como pagado. \(error.localizedDescription)")
        }
    }
}
