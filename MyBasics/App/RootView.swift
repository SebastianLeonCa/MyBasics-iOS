import SwiftUI

/// Raíz: según la sesión muestra Login o la app. Al cambiar de usuario, la app se recrea
/// (`.id(userId)`), así no quedan datos de la cuenta anterior en memoria.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var env = env
        Group {
            switch env.sessionState {
            case .loading:
                ThemedBackground()
                    .overlay { ProgressView().tint(Theme.accent) }
            case .signedOut:
                LoginView(environment: env)
                    .transition(.opacity)
            case .signedIn(let userId):
                SignedInView(environment: env)
                    .id(userId)
                    .transition(.opacity)
            }
        }
        .animation(Motion.isReduced ? nil : .smooth, value: env.sessionState)
        .task { await env.start() }
        .onOpenURL { url in
            Task { await env.handleOpenURL(url) }
        }
        .sheet(isPresented: $env.isRecoveringPassword) {
            NewPasswordView()
        }
        .errorAlert($env.linkMessage)
        .errorAlert($env.currencyError)
        // La moneda del perfil llega a todas las vistas (y hojas) por el entorno:
        // al cambiarla, toda la interfaz se redibuja al instante.
        .environment(\.currency, env.currency)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear { Motion.isReduced = reduceMotion }
        .onChange(of: reduceMotion) { _, value in Motion.isReduced = value }
    }
}

/// La app con sesión iniciada: pestañas personalizadas + hoja de nuevo/editar gasto.
struct SignedInView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var homeViewModel: HomeViewModel
    @State private var tab: AppTab = .home
    @State private var editor: ExpenseEditorRoute?

    init(environment: AppEnvironment) {
        let auth = environment.authService
        _homeViewModel = State(initialValue: HomeViewModel(
            repository: environment.expenseRepository,
            cache: environment.expenseCache,
            userId: { auth.currentUserId }))
    }

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeView(
                    viewModel: homeViewModel,
                    onEdit: { editor = ExpenseEditorRoute(expense: $0) },
                    onAdd: { editor = ExpenseEditorRoute(expense: nil) }
                )
            case .shared:
                SharedView(repository: env.expenseRepository)
            case .subscriptions:
                SubscriptionsView(repository: env.expenseRepository)
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $tab) {
                editor = ExpenseEditorRoute(expense: nil)
            }
        }
        .task { await env.loadCurrency() }
        .sheet(item: $editor) { route in
            AddExpenseView(
                viewModel: AddExpenseViewModel(
                    editing: route.expense,
                    categoryRepository: env.categoryRepository,
                    currency: env.currency
                ),
                onSubmit: { expense in
                    // Guardado optimista: Inicio lo muestra ya y revierte si el servidor falla.
                    Task { await homeViewModel.save(expense, isNew: route.expense == nil) }
                    // Las otras pestañas recargan al abrirse; si estás en una, volvemos a Inicio.
                    if tab != .home && route.expense == nil { tab = .home }
                }
            )
        }
    }
}

/// Qué abre la hoja: nil = gasto nuevo, o el gasto a editar.
struct ExpenseEditorRoute: Identifiable {
    let id = UUID()
    let expense: Expense?
}
