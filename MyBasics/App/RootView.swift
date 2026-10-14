import SwiftUI

/// Contenedor principal: pestañas personalizadas + hoja de nuevo/editar gasto.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var homeViewModel: HomeViewModel
    @State private var tab: AppTab = .home
    @State private var editor: ExpenseEditorRoute?

    init(environment: AppEnvironment) {
        _homeViewModel = State(initialValue: HomeViewModel(repository: environment.expenseRepository))
    }

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeView(
                    viewModel: homeViewModel,
                    currency: env.currency,
                    onEdit: { editor = ExpenseEditorRoute(expense: $0) },
                    onAdd: { editor = ExpenseEditorRoute(expense: nil) }
                )
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
                    expenseRepository: env.expenseRepository,
                    categoryRepository: env.categoryRepository,
                    currency: env.currency
                ),
                onSaved: { saved in
                    homeViewModel.didSave(saved)
                    // Al crear un gasto desde Ajustes, volvemos a Inicio para verlo.
                    tab = .home
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
