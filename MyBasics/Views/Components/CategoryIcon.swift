import SwiftUI

/// Símbolo de la categoría en blanco sobre un círculo de su color. Escala con Dynamic Type.
struct CategoryIcon: View {
    let icon: String
    let colorHex: String
    @ScaledMetric private var size: CGFloat

    init(icon: String, colorHex: String, size: CGFloat = 36) {
        self.icon = icon
        self.colorHex = colorHex
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    init(category: Category, size: CGFloat = 36) {
        self.init(icon: category.icon, colorHex: category.colorHex, size: size)
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex) ?? .gray, in: Circle())
            .accessibilityHidden(true)
    }
}
