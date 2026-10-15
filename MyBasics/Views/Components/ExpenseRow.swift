import SwiftUI

/// Fila estilo app bancaria: ícono, descripción, etiqueta Fijo/Variable, indicador de deuda y monto.
struct ExpenseRow: View {
    let expense: Expense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveStack {
            CategoryIcon(
                icon: expense.category?.icon ?? "tag",
                colorHex: expense.category?.colorHex ?? "#8E8E93"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    KindBadge(kind: expense.kind)
                    if expense.hasPendingDebt, let debt = expense.debts.first(where: { !$0.isSettled }) {
                        Label(debt.counterpartyName, systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

            Text(CurrencyFormatter.string(fromCents: expense.amountCents, currency: expense.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [
            expense.displayTitle,
            CurrencyFormatter.string(fromCents: expense.amountCents, currency: expense.currency),
            expense.kind.displayName,
        ]
        if let category = expense.category?.displayName, category != expense.displayTitle { parts.insert(category, at: 1) }
        if let debt = expense.debts.first(where: { !$0.isSettled }) {
            parts.append(debt.direction == .theyOweMe
                ? String(localized: "\(debt.counterpartyName) te debe")
                : String(localized: "Le debes a \(debt.counterpartyName)"))
        }
        return parts.joined(separator: ", ")
    }
}
