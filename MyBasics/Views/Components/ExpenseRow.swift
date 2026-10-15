import SwiftUI

/// Fila estilo app bancaria: ícono, descripción, etiqueta Fijo/Variable, estado del compartido y monto.
/// El monto es lo que de verdad te costó: si te devolvieron parte, se ve el neto y el original tachado.
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
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                KindBadge(kind: expense.kind)
                // En su propia línea para que no se corte.
                if let status = sharedStatus {
                    Label(status.text, systemImage: status.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }

            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(money(expense.netAmountCents))
                    .font(Theme.amount(.body, weight: .semibold))
                if expense.reimbursedCents > 0 {
                    Text(money(expense.amountCents))
                        .font(Theme.amount(.caption, weight: .medium))
                        .strikethrough()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private struct SharedStatus {
        let text: String
        let icon: String
        let color: Color
    }

    /// Solo lo pendiente (es lo accionable). Lo que ya te devolvieron se nota en el monto tachado.
    private var sharedStatus: SharedStatus? {
        if let debt = expense.debts.first(where: { !$0.isSettled }) {
            return debt.direction == .theyOweMe
                ? SharedStatus(
                    text: String(localized: "\(debt.counterpartyName) te debe \(money(debt.amountCents))"),
                    icon: "arrow.down.left", color: Theme.positive)
                : SharedStatus(
                    text: String(localized: "Le debes a \(debt.counterpartyName)"),
                    icon: "arrow.up.right", color: Theme.negative)
        }
        return nil
    }

    private func money(_ cents: Int) -> String {
        CurrencyFormatter.string(fromCents: cents, currency: expense.currency)
    }

    private var accessibilityText: String {
        var parts = [expense.displayTitle, money(expense.netAmountCents), expense.kind.displayName]
        if let category = expense.category?.displayName, category != expense.displayTitle { parts.insert(category, at: 1) }
        if expense.reimbursedCents > 0 {
            parts.append(String(localized: "Pagaste \(money(expense.amountCents))"))
        }
        if let status = sharedStatus { parts.append(status.text) }
        return parts.joined(separator: ", ")
    }
}
