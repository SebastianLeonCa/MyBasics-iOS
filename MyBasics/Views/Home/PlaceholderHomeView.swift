import SwiftUI

/// Pantalla temporal de la Fase 0: confirma que el entorno, los repositorios mock
/// y las utilidades funcionan. Se reemplaza por HomeView en la Fase 1.
struct PlaceholderHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var categories: [Category] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(Date.now.monthTitle())
                            .font(.title2.bold())
                        Text(CurrencyFormatter.string(fromCents: 250_000, currency: env.currency))
                            .font(.largeTitle.monospacedDigit())
                            .accessibilityLabel("Monto de ejemplo: \(CurrencyFormatter.string(fromCents: 250_000, currency: env.currency))")
                        Text("Fase 0 · base del proyecto")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }

                Section("Categorías por defecto (mock)") {
                    ForEach(categories) { category in
                        Label {
                            Text(category.name)
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color(hex: category.colorHex) ?? .gray, in: Circle())
                        }
                    }
                }
            }
            .navigationTitle("MyBasics")
            .task {
                categories = (try? await env.categoryRepository.fetchCategories()) ?? []
            }
        }
    }
}

#Preview {
    PlaceholderHomeView()
        .environment(AppEnvironment.mock())
}
