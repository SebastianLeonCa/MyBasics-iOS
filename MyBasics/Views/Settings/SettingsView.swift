import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CategoriesView(repository: env.categoryRepository)
                    } label: {
                        Label("Categorías", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        DebtsView(repository: env.expenseRepository, currency: env.currency)
                    } label: {
                        Label("Deudas", systemImage: "person.2")
                    }
                }

                Section {
                    LabeledContent("Moneda", value: env.currency)
                } footer: {
                    Text("Datos de ejemplo en memoria: se reinician al cerrar la app.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
