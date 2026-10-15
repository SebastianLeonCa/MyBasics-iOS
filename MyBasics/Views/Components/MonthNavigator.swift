import SwiftUI

/// ‹ Octubre 2026 ›
struct MonthNavigator: View {
    let title: String
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            chevron("chevron.left", action: onPrevious)
                .accessibilityLabel("Mes anterior")

            Spacer()

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Spacer()

            chevron("chevron.right", action: onNext)
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.3)
                .accessibilityLabel("Mes siguiente")
        }
        .buttonStyle(.borderless)
    }

    private func chevron(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.surfaceRaised, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                .frame(width: 44, height: 44)
        }
    }
}
