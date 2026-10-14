import SwiftUI

/// Etiqueta "Fijo" / "Variable".
struct KindBadge: View {
    let kind: ExpenseKind

    var body: some View {
        Text(kind.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(kind == .fixed ? Color.indigo : Color.secondary)
            .background(
                (kind == .fixed ? Color.indigo : Color.secondary).opacity(0.15),
                in: Capsule()
            )
    }
}
