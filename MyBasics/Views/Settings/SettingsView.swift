import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CategoriesView(repository: env.categoryRepository)
                    } label: {
                        Label("Categorías", systemImage: "square.grid.2x2")
                    }
                }

                Section {
                    LabeledContent("Moneda", value: env.currency)
                    Button {
                        // Abre los ajustes de la app en iOS, donde se elige el idioma de la app.
                        if let url = URL(string: "app-settings:") { openURL(url) }
                    } label: {
                        LabeledContent("Idioma", value: currentLanguageName)
                    }
                    .foregroundStyle(.primary)
                } footer: {
                    Text("El idioma se cambia en Ajustes de iOS › MyBasics › Idioma. Datos de ejemplo en memoria: se reinician al cerrar la app.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "es"
        return Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }
}
