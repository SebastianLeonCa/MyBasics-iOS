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

/// Barra inferior flotante: dos pestañas a cada lado de un botón "+" redondo y brillante.
struct CustomTabBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void
    @State private var addTaps = 0

    @ScaledMetric(relativeTo: .title) private var plusSize: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(.home)
            tabButton(.shared)
            addButton
                .padding(.horizontal, 6)
                .offset(y: -14)
            tabButton(.subscriptions)
            tabButton(.settings)
        }
        .padding(.horizontal, 8)
        .frame(height: 64)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.surface.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .background(alignment: .bottom) {
            // Difumina el contenido que pasa por debajo de la barra.
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
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
                .font(.system(size: plusSize * 0.4, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: plusSize, height: plusSize)
                .background(Theme.accentGradient, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Theme.accent.opacity(0.55), radius: 14, y: 4)
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
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer {
            Image(systemName: tab.icon)
            Text(tab.title)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
