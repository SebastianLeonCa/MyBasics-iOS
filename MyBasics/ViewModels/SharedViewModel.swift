import SwiftUI

/// Pantalla "Compartidos": quién me debe y a quién le debo, por gastos compartidos.
@Observable
final class SharedViewModel {
    private let repository: any ExpenseRepository

    private(set) var shares: [PendingShare] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var loadError: String?
    var alert: UserFacingError?

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
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            if hasLoaded {
                alert = UserFacingError(error, retry: { [weak self] in await self?.load() })
            } else {
                loadError = UserFacingError.describe(error)
            }
        }
    }

    /// Marca como pagado; se quita de la lista al instante y vuelve si el servidor falla.
    func markPaid(_ share: PendingShare) async {
        withAnimation(.smooth) { shares.removeAll { $0.id == share.id } }
        do {
            try await repository.settleDebt(id: share.debt.id)
        } catch {
            withAnimation(.smooth) { shares.append(share) }   // el orden lo recalcula `balances`
            alert = UserFacingError(
                error,
                title: String(localized: "No se pudo marcar como pagado"),
                retry: { [weak self] in await self?.markPaid(share) })
        }
    }
}
