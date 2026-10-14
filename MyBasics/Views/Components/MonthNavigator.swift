import SwiftUI

/// ‹ Octubre 2026 ›
struct MonthNavigator: View {
    let title: String
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mes anterior")

            Spacer()

            Text(title)
                .font(.headline)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Mes siguiente")
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.borderless)
    }
}
