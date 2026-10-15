import SwiftUI

/// Contenedor principal: pestañas personalizadas + hoja de nuevo/editar gasto.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var homeViewModel: HomeViewModel
    @State private var tab: AppTab = .home
    @State private var editor: ExpenseEditorRoute?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(environment: AppEnvironment) {
        let auth = environment.authService
        _homeViewModel = State(initialValue: HomeViewModel(
            repository: environment.expenseRepository,
            cache: environment.expenseCache,
            userId: { auth.currentUserId }))
    }

    var body: some View {
        sessionContent
            .onAppear { Motion.isReduced = reduceMotion }
            .onChange(of: reduceMotion) { _, value in Motion.isReduced = value }
    }

    @ViewBuilder
    private var sessionContent: some View {
        switch env.sessionState {
        case .ready:
            content
        case .signingIn:
            ProgressView("Conectando…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await env.start() }
        case .failed(let message):
            ContentUnavailableView {
                Label("No se pudo conectar", systemImage: "icloud.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { Task { await env.start() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var content: some View {
        Group {
            switch tab {
            case .home:
                HomeView(
                    viewModel: homeViewModel,
                    currency: env.currency,
                    onEdit: { editor = ExpenseEditorRoute(expense: $0) },
                    onAdd: { editor = ExpenseEditorRoute(expense: nil) }
                )
            case .shared:
                SharedView(repository: env.expenseRepository, currency: env.currency)
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
