import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var confirmingSignOut = false
    /// Moneda elegida en la lista, a la espera de confirmación.
    @State private var pendingCurrency: String?
    @State private var confirmingDelete = false
    @State private var isWorking = false
    @State private var alert: UserFacingError?

    var body: some View {
        @Bindable var env = env
        NavigationStack {
            List {
                Group {
                    Section {
                        Picker(selection: Binding(
                        get: { env.currency },
                        // No se aplica todavía: primero se confirma.
                        set: { pendingCurrency = $0 }
                    )) {
                        ForEach(CurrencyOptions.codes, id: \.self) { code in
                            Text(verbatim: "\(CurrencyFormatter.name(for: code)) (\(CurrencyFormatter.symbol(for: code)))").tag(code)
                        }
                    } label: {
                        Label("Moneda", systemImage: "dollarsign.circle")
                    }
                    .pickerStyle(.navigationLink)
                    } footer: {
                        Text("Es el símbolo con el que se muestran todos tus montos. Cambiarla no convierte ningún valor.")
                    }

                    Section {
                        NavigationLink {
                            CategoriesView(repository: env.categoryRepository)
                        } label: {
                            Label("Categorías", systemImage: "square.grid.2x2")
                        }
                        NavigationLink {
                            ExportView(repository: env.expenseRepository)
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

                    accountSection

                    Section {
                        LabeledContent("Versión", value: appVersion)
                    }
                }
                .themedRows()
            }
            .navigationTitle("Ajustes")
            .themedScreen()
            .disabled(isWorking)
            .overlay { if isWorking { ProgressView().controlSize(.large).tint(Theme.accent) } }
            .alert(
                currencyAlertTitle,
                isPresented: Binding(get: { pendingCurrency != nil }, set: { if !$0 { pendingCurrency = nil } }),
                presenting: pendingCurrency
            ) { code in
                Button("Cancelar", role: .cancel) {}
                Button("Cambiar a \(CurrencyFormatter.symbol(for: code))") {
                    Task { await env.changeCurrency(to: code) }
                }
            } message: { code in
                Text("Solo cambiará el símbolo con el que se muestran tus montos. No se hará ninguna conversión: si tenías \(CurrencyFormatter.string(fromCents: 10_000, currency: env.currency)), verás \(CurrencyFormatter.string(fromCents: 10_000, currency: code)).")
            }
            .alert("¿Seguro que quieres cerrar sesión?", isPresented: $confirmingSignOut) {
                Button("No", role: .cancel) {}
                Button("Sí, cerrar sesión", role: .destructive) { run(env.signOut) }
            } message: {
                Text("Tus datos quedan guardados en tu cuenta; vuelve a entrar cuando quieras.")
            }
            .alert("¿Eliminar tu cuenta?", isPresented: $confirmingDelete) {
                Button("Eliminar cuenta", role: .destructive) { run(env.deleteAccount) }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se borrarán para siempre tu cuenta, tus gastos, categorías y compartidos. No se puede deshacer.")
            }
            .errorAlert($alert)
        }
    }

    private var currencyAlertTitle: String {
        guard let code = pendingCurrency else { return "" }
        return String(localized: "¿Cambiar moneda a \(CurrencyFormatter.name(for: code)) (\(CurrencyFormatter.symbol(for: code)))?")
    }

    private var accountSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: env.authService.currentUserEmail ?? "—")
                    .lineLimit(1)
                    .truncationMode(.middle)
            } label: {
                Label("Cuenta", systemImage: "person.crop.circle")
            }
            Button("Cerrar sesión") { confirmingSignOut = true }
            Button("Eliminar cuenta", role: .destructive) { confirmingDelete = true }
        } footer: {
            Text("Eliminar la cuenta borra todos tus datos de forma permanente.")
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await action()
            } catch {
                alert = UserFacingError(error)
            }
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
