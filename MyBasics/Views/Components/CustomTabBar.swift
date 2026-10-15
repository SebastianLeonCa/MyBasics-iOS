import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home, shared, subscriptions, settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Inicio"
        case .shared: "Compartidos"
        case .subscriptions: "Suscripciones"
        case .settings: "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .shared: "person.2"
        case .subscriptions: "repeat.circle"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String { icon + ".fill" }
}

/// Barra inferior: dos pestañas a cada lado de un botón "+" redondo y flotante.
struct CustomTabBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void
    @State private var addTaps = 0

    @ScaledMetric(relativeTo: .title) private var plusSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.home)
            tabButton(.shared)
            Color.clear.frame(width: plusSize + 12, height: 1)
            tabButton(.subscriptions)
            tabButton(.settings)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(alignment: .top) {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) { Divider() }
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { addButton.offset(y: -plusSize / 2) }
        // Como la barra estándar de iOS: tamaño acotado y, con texto grande, pulsación larga
        // muestra el "Visor de contenido grande".
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .sensoryFeedback(.selection, trigger: selection)
        .sensoryFeedback(.impact(weight: .light), trigger: addTaps)
    }

    private var addButton: some View {
        Button {
            addTaps += 1
            onAdd()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: plusSize * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: plusSize, height: plusSize)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                .symbolEffect(.bounce, value: addTaps)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Nuevo gasto")
        .accessibilityShowsLargeContentViewer {
            Image(systemName: "plus")
            Text("Nuevo gasto")
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                    .font(.title3)
                    .symbolEffect(.bounce, value: selection == tab)
                Text(tab.title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer {
            Image(systemName: tab.icon)
            Text(tab.title)
        }
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
