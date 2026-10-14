import Observation
import SwiftUI

/// Contenedor de dependencias. Las vistas lo leen con `@Environment(AppEnvironment.self)`.
/// Cambiar de Mock a Supabase (Fase 2) se hace solo aquí.
@Observable
final class AppEnvironment {
    let expenseRepository: any ExpenseRepository
    let categoryRepository: any CategoryRepository
    let authService: any AuthService

    /// Moneda configurable (Ajustes llega en la Fase 3).
    var currency: String = CurrencyFormatter.defaultCurrency

    init(
        expenseRepository: any ExpenseRepository,
        categoryRepository: any CategoryRepository,
        authService: any AuthService
    ) {
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.authService = authService
    }

    /// Todo en memoria, sin red. Es el default de la app por ahora.
    /// `withSampleData: false` arranca vacío (útil para ver el estado vacío).
    static func mock(withSampleData: Bool = true) -> AppEnvironment {
        let categories = MockCategoryRepository()
        let expenses = withSampleData ? MockData.expenses(categories: categories.categories) : []
        return AppEnvironment(
            expenseRepository: MockExpenseRepository(expenses: expenses, categories: { categories.categories }),
            categoryRepository: categories,
            authService: MockAuthService()
        )
    }
}
