import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var env = env
        NavigationStack {
            List {
                Section {
                    Picker(selection: $env.currency) {
                        ForEach(CurrencyOptions.codes, id: \.self) { code in
                            Text(verbatim: CurrencyOptions.displayName(for: code)).tag(code)
                        }
                    } label: {
                        Label("Moneda", systemImage: "dollarsign.circle")
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("Se usa en los gastos nuevos y en los totales. Los gastos ya guardados conservan su moneda.")
                }

                Section {
                    NavigationLink {
                        CategoriesView(repository: env.categoryRepository)
                    } label: {
                        Label("Categorías", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        ExportView(repository: env.expenseRepository, currency: env.currency)
                    } label: {
                        Label("Exportar mes (CSV)", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Button {
                        // Abre los ajustes de la app en iOS, donde se elige el idioma de la app.
                        if let url = URL(string: "app-settings:") { openURL(url) }
                    } label: {
                        LabeledContent {
                            Text(verbatim: currentLanguageName)
                        } label: {
                            Label("Idioma", systemImage: "globe")
                        }
                    }
                    .foregroundStyle(.primary)
                    LabeledContent {
                        Text(env.dataSource == .supabase ? "Supabase" : String(localized: "Ejemplo (sin conexión)"))
                    } label: {
                        Label("Datos", systemImage: env.dataSource == .supabase ? "icloud" : "internaldrive")
                    }
                } footer: {
                    if env.dataSource == .supabase {
                        Text("El idioma se cambia en Ajustes de iOS › MyBasics › Idioma.")
                    } else {
                        Text("El idioma se cambia en Ajustes de iOS › MyBasics › Idioma. Datos de ejemplo en memoria: se reinician al cerrar la app. Completa Config/Secrets.xcconfig para usar Supabase.")
                    }
                }

                Section {
                    LabeledContent("Versión", value: appVersion)
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "es"
        return Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
