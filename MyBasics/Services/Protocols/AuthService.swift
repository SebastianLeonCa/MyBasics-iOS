import Foundation

/// Cambios de sesión que la app escucha para mostrar Login o Inicio.
enum AuthEvent: Equatable {
    case signedIn(UUID)
    case signedOut
}

enum SignUpResult: Equatable {
    /// La cuenta quedó activa y con sesión (confirmación de correo desactivada).
    case signedIn
    /// Se envió un correo de confirmación; la sesión empieza al tocar el enlace.
    case needsEmailConfirmation
}

/// Qué tipo de enlace de correo abrió la app.
enum AuthLink: Equatable {
    case emailConfirmed
    case passwordRecovery
}

/// Autenticación. Implementaciones: Mock (sin red) y Supabase.
protocol AuthService: AnyObject {
    var currentUserId: UUID? { get }
    var currentUserEmail: String? { get }

    /// Flujo de cambios de sesión (inicio, cierre, sesión expirada, cuenta eliminada…).
    func events() -> AsyncStream<AuthEvent>
    /// Recupera la sesión guardada en el Keychain, si existe.
    func restoreSession() async -> UUID?

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func signInWithGoogle(idToken: String, accessToken: String, rawNonce: String) async throws
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws -> SignUpResult
    func sendPasswordReset(email: String) async throws
    func updatePassword(_ password: String) async throws
    /// Procesa un enlace mybasics://… de confirmación o recuperación. nil si no es un enlace de auth.
    func handle(_ url: URL) async throws -> AuthLink?

    func signOut() async throws
    /// Elimina la cuenta y todos sus datos (requisito de App Store).
    func deleteAccount() async throws
}

extension AuthService {
    var isSignedIn: Bool { currentUserId != nil }
}

/// Direcciones a las que vuelven los enlaces de correo. Deben estar en
/// Supabase › Authentication › URL Configuration › Redirect URLs.
nonisolated enum AuthRedirect {
    static let scheme = "mybasics"
    static let emailConfirmation = URL(string: "mybasics://auth-callback")!
    static let passwordReset = URL(string: "mybasics://reset-password")!
}
