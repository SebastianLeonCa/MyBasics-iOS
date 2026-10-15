import Observation
import SwiftUI

/// Contenedor de dependencias. Las vistas lo leen con `@Environment(AppEnvironment.self)`.
/// Elegir entre Mock y Supabase se hace solo aquí.
@Observable
final class AppEnvironment {
    enum DataSource {
        case mock, supabase
    }

    enum SessionState: Equatable {
        /// Leyendo la sesión guardada (un instante al abrir la app).
        case loading
        case signedOut
        case signedIn(UUID)
    }

    let expenseRepository: any ExpenseRepository
    let categoryRepository: any CategoryRepository
    let authService: any AuthService
    let dataSource: DataSource
    /// Caché local del mes en curso (nil = sin caché, p. ej. en modo de ejemplo).
    let expenseCache: (any ExpenseCache)?
    /// Client ID de Google (tipo iOS). nil = se oculta "Continuar con Google".
    let googleIOSClientID: String?

    private(set) var sessionState: SessionState = .loading
    /// Se abrió un enlace de "olvidé mi contraseña": hay que pedir la nueva.
    var isRecoveringPassword = false
    /// Mensaje tras abrir un enlace de confirmación (p. ej. "Correo confirmado").
    var linkMessage: UserFacingError?

    private var eventsTask: Task<Void, Never>?
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
        googleIOSClientID: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.authService = authService
        self.dataSource = dataSource
        self.expenseCache = expenseCache
        self.googleIOSClientID = googleIOSClientID
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
        let signedOut = ProcessInfo.processInfo.arguments.contains("-mockSignedOut")
        return mock(signedIn: !signedOut)
    }

    static func supabase(_ config: SupabaseConfig) -> AppEnvironment {
        let client = SupabaseClientFactory.make(config)
        return AppEnvironment(
            expenseRepository: SupabaseExpenseRepository(client: client),
            categoryRepository: SupabaseCategoryRepository(client: client),
            authService: SupabaseAuthService(client: client),
            dataSource: .supabase,
            expenseCache: FileExpenseCache(),
            googleIOSClientID: config.googleIOSClientID
        )
    }

    /// Todo en memoria, sin red.
    /// `withSampleData: false` arranca vacío (útil para ver el estado vacío).
    static func mock(
        withSampleData: Bool = true,
        signedIn: Bool = true,
        defaults: UserDefaults = .standard
    ) -> AppEnvironment {
        let categories = MockCategoryRepository()
        let expenses = withSampleData ? MockData.expenses(categories: categories.categories) : []
        return AppEnvironment(
            expenseRepository: MockExpenseRepository(expenses: expenses, categories: { categories.categories }),
            categoryRepository: categories,
            authService: MockAuthService(signedIn: signedIn),
            dataSource: .mock,
            defaults: defaults
        )
    }

    // MARK: - Sesión

    /// Al abrir la app: recupera la sesión del Keychain y empieza a escuchar cambios.
    func start() async {
        if eventsTask == nil {
            let stream = authService.events()
            eventsTask = Task { [weak self] in
                for await event in stream { self?.apply(event) }
            }
        }
        if sessionState == .loading {
            sessionState = await authService.restoreSession().map { .signedIn($0) } ?? .signedOut
        }
    }

    private func apply(_ event: AuthEvent) {
        switch event {
        case .signedIn(let id):
            if sessionState != .signedIn(id) { sessionState = .signedIn(id) }
        case .signedOut:
            expenseCache?.removeAll()
            isRecoveringPassword = false
            sessionState = .signedOut
        }
    }

    /// Para los inicios de sesión que no pasan por el flujo de eventos (o por si llega tarde).
    func syncSession() {
        sessionState = authService.currentUserId.map { .signedIn($0) } ?? .signedOut
    }

    func signOut() async throws {
        try await authService.signOut()
        expenseCache?.removeAll()
        syncSession()
    }

    func deleteAccount() async throws {
        try await authService.deleteAccount()
        expenseCache?.removeAll()
        syncSession()
    }

    /// Enlace mybasics://… abierto desde el correo.
    func handleOpenURL(_ url: URL) async {
        do {
            switch try await authService.handle(url) {
            case .passwordRecovery:
                syncSession()
                isRecoveringPassword = true
            case .emailConfirmed:
                syncSession()
                linkMessage = UserFacingError(
                    title: String(localized: "Correo confirmado"),
                    message: String(localized: "¡Listo! Tu cuenta está activa."))
            case nil:
                break
            }
        } catch {
            linkMessage = UserFacingError(
                error, title: String(localized: "El enlace no es válido o ya expiró"))
        }
    }
}
