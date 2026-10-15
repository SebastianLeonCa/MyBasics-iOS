import SwiftUI

/// Leyenda del gráfico: color, nombre, monto y %; ordenada de mayor a menor. Cada fila también selecciona.
struct CategoryLegendView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let totals: [CategoryTotal]
    let currency: String
    let selectedCategoryId: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(totals) { item in
                Button {
                    onSelect(item.categoryId)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: item.colorHex) ?? .gray)
                            .frame(width: 10, height: 10)
                        AdaptiveStack(spacing: 10) {
                            Text(verbatim: item.name)
                                .foregroundStyle(.primary)
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            HStack(spacing: 10) {
                                Text(CurrencyFormatter.string(fromCents: item.amountCents, currency: currency))
                                    .font(Theme.amount(.subheadline, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(item.share.formatted(.percent.precision(.fractionLength(0))))
                                    .font(Theme.amount(.subheadline, weight: .medium))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(minWidth: 44, alignment: .trailing)
                            }
                        }
                        if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    }
                    .font(.subheadline)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(
                        item.categoryId == selectedCategoryId ? Theme.surfaceRaised : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item.categoryId == selectedCategoryId ? .isSelected : [])
            }
        }
    }
}
