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
                    // Inicio refleja el cambio al instante. Las otras pestañas recargan al abrirse;
                    // si estás en una, volvemos a Inicio para ver el gasto nuevo.
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
