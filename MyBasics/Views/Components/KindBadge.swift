import SwiftUI

/// Etiqueta "Fijo" / "Variable".
struct KindBadge: View {
    let kind: ExpenseKind

    var body: some View {
        Text(kind.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(kind == .fixed ? Theme.accent : Theme.textSecondary)
            .background(
                (kind == .fixed ? Theme.accent : Color.white).opacity(kind == .fixed ? 0.14 : 0.08),
                in: Capsule()
            )
    }
}
