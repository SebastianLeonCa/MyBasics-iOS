import Foundation

@Observable
final class SubscriptionsViewModel {
    private let repository: any ExpenseRepository
    private let now: () -> Date

    private(set) var summaries: [SubscriptionSummary] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(repository: any ExpenseRepository, now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.now = now
    }

    var active: [SubscriptionSummary] { summaries.filter(\.isActive) }
    var inactive: [SubscriptionSummary] { summaries.filter { !$0.isActive } }
    var monthlyTotalCents: Int { SubscriptionAnalytics.monthlyActiveTotal(summaries) }
    /// Moneda del total (la de la suscripción activa más reciente).
    var currency: String? { active.first?.currency }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let now = now()
            let expenses = try await repository.fetchExpenses(in: SubscriptionAnalytics.lookbackInterval(now: now))
            summaries = SubscriptionAnalytics.summaries(from: expenses, now: now)
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
