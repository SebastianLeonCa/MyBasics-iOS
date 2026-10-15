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
    let profileRepository: any ProfileRepository
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

    /// Moneda con la que se muestran TODOS los montos. Única fuente de verdad: `profiles.currency`
    /// en Supabase, con una copia local por usuario para abrir al instante y sin conexión.
    /// Cambiarla es solo cambiar el símbolo: los montos guardados no se convierten.
    private(set) var currency: String = CurrencyFormatter.defaultCurrency
    /// Error al guardar la moneda (se revierte el cambio).
    var currencyError: UserFacingError?

    init(
        expenseRepository: any ExpenseRepository,
        categoryRepository: any CategoryRepository,
        authService: any AuthService,
        profileRepository: any ProfileRepository = MockProfileRepository(),
        dataSource: DataSource,
        expenseCache: (any ExpenseCache)? = nil,
        googleIOSClientID: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.authService = authService
        self.profileRepository = profileRepository
        self.dataSource = dataSource
        self.expenseCache = expenseCache
        self.googleIOSClientID = googleIOSClientID
        self.defaults = defaults
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
            profileRepository: SupabaseProfileRepository(client: client),
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
            profileRepository: MockProfileRepository(),
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

    // MARK: - Moneda (perfil)

    private func currencyCacheKey(_ userId: UUID) -> String { "currency.\(userId.uuidString)" }

    /// Al entrar: muestra al instante la moneda guardada en el dispositivo y luego la confirma
    /// con el perfil del servidor (por si se cambió en otro dispositivo).
    func loadCurrency() async {
        guard let userId = authService.currentUserId else { return }
        if let cached = defaults.string(forKey: currencyCacheKey(userId)) { currency = cached }
        do {
            if let remote = try await profileRepository.fetchCurrency(), authService.currentUserId == userId {
                currency = remote
                defaults.set(remote, forKey: currencyCacheKey(userId))
            }
        } catch {
            // Sin conexión: se queda la copia local. No hace falta molestar con un error.
        }
    }

    /// Cambia la moneda: se ve al instante en toda la app; si el servidor falla, se revierte.
    func changeCurrency(to newCurrency: String) async {
        guard newCurrency != currency, let userId = authService.currentUserId else { return }
        let previous = currency
        currency = newCurrency
        defaults.set(newCurrency, forKey: currencyCacheKey(userId))
        do {
            try await profileRepository.updateCurrency(newCurrency)
        } catch {
            currency = previous
            defaults.set(previous, forKey: currencyCacheKey(userId))
            currencyError = UserFacingError(
                error,
                title: String(localized: "No se pudo cambiar la moneda"),
                retry: { [weak self] in await self?.changeCurrency(to: newCurrency) })
        }
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
