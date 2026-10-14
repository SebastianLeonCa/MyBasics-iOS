import SwiftUI

/// Leyenda del gráfico: color, nombre, monto y %; ordenada de mayor a menor. Cada fila también selecciona.
struct CategoryLegendView: View {
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
                        Text(verbatim: item.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(CurrencyFormatter.string(fromCents: item.amountCents, currency: currency))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(item.share.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        item.categoryId == selectedCategoryId ? Color.secondary.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item.categoryId == selectedCategoryId ? .isSelected : [])
            }
        }
    }
}
