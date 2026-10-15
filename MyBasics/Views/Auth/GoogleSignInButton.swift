import SwiftUI

/// Botón "Continuar con Google" según la guía de marca de Google (logo G oficial,
/// fondo #FFFFFF / borde #747775 en claro; fondo #131314 / borde #8E918F en oscuro).
struct GoogleSignInButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("GoogleG")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("Continuar con Google")
                    .font(.system(size: 19, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isDark ? Color(hex: "#E3E3E3")! : Color(hex: "#1F1F1F")!)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isDark ? Color(hex: "#131314")! : .white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDark ? Color(hex: "#8E918F")! : Color(hex: "#747775")!, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var isDark: Bool { colorScheme == .dark }
}
