import SwiftUI

enum AppTab: Hashable {
    case home, settings
}

/// Barra inferior: Inicio (izq), botón "+" redondo flotante (centro) y Ajustes (der).
struct CustomTabBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void

    @ScaledMetric(relativeTo: .title) private var plusSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .bottom) {
            tabButton(.home, title: "Inicio", icon: "house")
            Color.clear.frame(width: plusSize + 16, height: 1)
            tabButton(.settings, title: "Ajustes", icon: "gearshape")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(alignment: .top) {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) { Divider() }
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { addButton.offset(y: -plusSize / 2) }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: plusSize * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: plusSize, height: plusSize)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Nuevo gasto")
    }

    private func tabButton(_ tab: AppTab, title: String, icon: String) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == tab ? "\(icon).fill" : icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
    }
}

/// Pequeño "hundimiento" al presionar.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
