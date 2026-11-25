import SwiftUI

/// Sistema de diseño de MyBasics (solo modo oscuro).
/// Fondo casi negro con un matiz verde, tarjetas elevadas con borde sutil y acento menta.
enum Theme {
    // Superficies
    static let background = Color(hex: "#0A0F0D")!
    static let surface = Color(hex: "#131B18")!
    static let surfaceRaised = Color(hex: "#1B2622")!
    static let stroke = Color.white.opacity(0.07)

    // Acento (menta) y su degradado para el botón principal
    static let accent = Color(hex: "#2FD8A3")!
    static let accentDeep = Color(hex: "#0F9E78")!
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#3BE6B0")!, Color(hex: "#0F9E78")!],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Texto
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    // Estados
    static let positive = Color(hex: "#3DDC97")!
    static let negative = Color(hex: "#FF8A65")!

    static let cornerRadius: CGFloat = 22
    static let rowCornerRadius: CGFloat = 16

    /// Montos y totales: SF Rounded, con dígitos de ancho fijo.
    static func amount(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}

/// Fondo de pantalla: color base + un brillo menta difuso arriba.
struct ThemedBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 420)
                .frame(height: 520)
                .offset(y: -140)
                .blur(radius: 20)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Para List/Form: oculta el fondo del sistema y usa el del tema.
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(ThemedBackground())
            .toolbarBackground(Theme.background.opacity(0.92), for: .navigationBar)
    }

    /// Fondo de las filas de una sección de List/Form.
    func themedRows() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.stroke)
    }

    /// Tarjeta independiente (fuera de una List).
    func card(padding: CGFloat = 16, cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self.padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

/// Selector segmentado tipo píldora, con la opción activa deslizándose (matchedGeometryEffect).
struct PillPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    Motion.animate(.snappy) { selection = option }
                } label: {
                    Text(verbatim: title(option))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
