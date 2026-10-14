import Foundation

/// Una suscripción deducida de los gastos de la categoría Suscripciones, agrupando por descripción.
nonisolated struct SubscriptionSummary: Identifiable, Hashable, Sendable {
    var id: String { key }
    /// Descripción normalizada (minúsculas, sin espacios extra).
    let key: String
    let name: String
    let icon: String
    let colorHex: String
    let currency: String
    /// Monto del último cobro.
    let lastAmountCents: Int
    let lastChargeAt: Date
    let chargeCount: Int
    let isActive: Bool
    /// Estimación: un mes después del último cobro.
    let nextChargeAt: Date
}

nonisolated enum SubscriptionAnalytics {
    /// Una suscripción está activa si tuvo un cobro en los últimos 35 días.
    static let activeWindowDays = 35

    /// Meses hacia atrás que se revisan para encontrar suscripciones.
    static let lookbackMonths = 6

    static func lookbackInterval(now: Date = .now, calendar: Calendar = .app) -> DateInterval {
        let end = now.addingMonths(1, calendar: calendar)
        let start = now.addingMonths(-(lookbackMonths - 1), calendar: calendar)
        return DateInterval(start: start, end: end)
    }

    /// Activas primero (mayor monto primero); luego inactivas (cobro más reciente primero).
    static func summaries(from expenses: [Expense], now: Date = .now, calendar: Calendar = .app) -> [SubscriptionSummary] {
        let activeSince = calendar.date(byAdding: .day, value: -activeWindowDays, to: now) ?? now
        let subscriptions = expenses.filter { $0.category?.isSubscriptions == true }

        let grouped = Dictionary(grouping: subscriptions) { expense in
            (expense.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        return grouped.compactMap { key, charges -> SubscriptionSummary? in
            guard let last = charges.max(by: { $0.spentAt < $1.spentAt }) else { return nil }
            let name = last.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SubscriptionSummary(
                key: key,
                name: (name?.isEmpty == false ? name : nil) ?? String(localized: "Suscripción"),
                icon: last.category?.icon ?? "repeat",
                colorHex: last.category?.colorHex ?? "#5E60CE",
                currency: last.currency,
                lastAmountCents: last.amountCents,
                lastChargeAt: last.spentAt,
                chargeCount: charges.count,
                isActive: last.spentAt >= activeSince,
                nextChargeAt: calendar.date(byAdding: .month, value: 1, to: last.spentAt) ?? last.spentAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            if lhs.isActive { return lhs.lastAmountCents != rhs.lastAmountCents
                ? lhs.lastAmountCents > rhs.lastAmountCents : lhs.name < rhs.name }
            return lhs.lastChargeAt > rhs.lastChargeAt
        }
    }

    /// Suma mensual de las suscripciones activas (último monto de cada una).
    static func monthlyActiveTotal(_ summaries: [SubscriptionSummary]) -> Int {
        summaries.filter(\.isActive).reduce(0) { $0 + $1.lastAmountCents }
    }
}
