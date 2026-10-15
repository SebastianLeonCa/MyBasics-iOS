import Observation
import SwiftUI

/// Contenedor de dependencias. Las vistas lo leen con `@Environment(AppEnvironment.self)`.
/// Elegir entre Mock y Supabase se hace solo aquí.
@Observable
final class AppEnvironment {
    enum DataSource {
        case mock, supabase
    }

    enum SessionState {
        case signingIn
        case ready
        case failed(String)
    }

    let expenseRepository: any ExpenseRepository
    let categoryRepository: any CategoryRepository
    let authService: any AuthService
    let dataSource: DataSource
    /// Caché local del mes en curso (nil = sin caché, p. ej. en modo de ejemplo).
    let expenseCache: (any ExpenseCache)?
    private(set) var sessionState: SessionState = .signingIn

    private let defaults: UserDefaults
    private static let currencyKey = "currency"

    /// Moneda de los gastos nuevos y de los totales. Se recuerda entre aperturas.
    var currency: String {
        didSet { defaults.set(currency, forKey: Self.currencyKey) }
    }

    init(
        expenseRepository: any ExpenseRepository,
        categoryRepository: any CategoryRepository,
        authService: any AuthService,
        dataSource: DataSource,
        expenseCache: (any ExpenseCache)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.authService = authService
        self.dataSource = dataSource
        self.expenseCache = expenseCache
        self.defaults = defaults
        self.currency = defaults.string(forKey: Self.currencyKey) ?? CurrencyFormatter.defaultCurrency
    }

    /// Supabase si Config/Secrets.xcconfig está completo; si no (o en tests), datos de ejemplo.
    static func makeDefault() -> AppEnvironment {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let forceMock = ProcessInfo.processInfo.arguments.contains("-useMockData")
        if !isRunningTests, !forceMock, let config = SupabaseConfig.fromBundle() {
            return supabase(config)
        }
        return mock()
    }

    static func supabase(_ config: SupabaseConfig) -> AppEnvironment {
        let client = SupabaseClientFactory.make(config)
        return AppEnvironment(
            expenseRepository: SupabaseExpenseRepository(client: client),
            categoryRepository: SupabaseCategoryRepository(client: client),
            authService: DevUserAuthService(client: client, email: config.devUserEmail, password: config.devUserPassword),
            dataSource: .supabase,
            expenseCache: FileExpenseCache()
        )
    }

    /// Todo en memoria, sin red.
    /// `withSampleData: false` arranca vacío (útil para ver el estado vacío).
    static func mock(withSampleData: Bool = true, defaults: UserDefaults = .standard) -> AppEnvironment {
        let categories = MockCategoryRepository()
        let expenses = withSampleData ? MockData.expenses(categories: categories.categories) : []
        return AppEnvironment(
            expenseRepository: MockExpenseRepository(expenses: expenses, categories: { categories.categories }),
            categoryRepository: categories,
            authService: MockAuthService(),
            dataSource: .mock,
            defaults: defaults
        )
    }

    /// Inicia sesión (en silencio). Se llama al abrir la app y desde "Reintentar".
    func start() async {
        if case .ready = sessionState, authService.isSignedIn { return }
        // Abrir rápido: con una sesión guardada se entra de inmediato (Inicio muestra la caché)
        // y la sesión se renueva en segundo plano. Si la renovación falla, las consultas lo avisan.
        if authService.isSignedIn {
            sessionState = .ready
            try? await authService.signIn()
            return
        }
        sessionState = .signingIn
        do {
            try await authService.signIn()
            sessionState = .ready
        } catch {
            sessionState = .failed(UserFacingError.describe(error))
        }
    }
}
