import Foundation

/// Autenticación en memoria (modo de ejemplo, previews y tests).
/// Cualquier email con contraseña de 8+ caracteres entra; "error@…" simula un fallo.
final class MockAuthService: AuthService {
    static let developmentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    enum MockError: LocalizedError {
        case invalidCredentials
        var errorDescription: String? { String(localized: "Email o contraseña incorrectos.") }
    }

    private(set) var currentUserId: UUID?
    private(set) var currentUserEmail: String?
    /// Si true, el registro pide confirmar el correo (como Supabase con confirmación activada).
    var requiresEmailConfirmation = false
    private(set) var deletedAccounts = 0
    private(set) var lastPasswordResetEmail: String?
    private var continuations: [UUID: AsyncStream<AuthEvent>.Continuation] = [:]

    init(signedIn: Bool = true) {
        if signedIn {
            currentUserId = Self.developmentUserId
            currentUserEmail = "demo@mybasics.app"
        }
    }

    func events() -> AsyncStream<AuthEvent> {
        let id = UUID()
        // Mock: los streams viven lo mismo que la app (o el test), así que no se limpian.
        return AsyncStream { continuation in
            continuations[id] = continuation
        }
    }

    func restoreSession() async -> UUID? { currentUserId }

    private func setSession(_ id: UUID?, email: String?) {
        currentUserId = id
        currentUserEmail = email
        let event: AuthEvent = id.map { .signedIn($0) } ?? .signedOut
        continuations.values.forEach { $0.yield(event) }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        setSession(UUID(), email: "apple@privaterelay.appleid.com")
    }

    func signInWithGoogle(idToken: String, accessToken: String, rawNonce: String) async throws {
        setSession(UUID(), email: "google@gmail.com")
    }

    func signIn(email: String, password: String) async throws {
        guard !email.hasPrefix("error@"), password.count >= 8 else { throw MockError.invalidCredentials }
        setSession(Self.developmentUserId, email: email)
    }

    func signUp(email: String, password: String) async throws -> SignUpResult {
        guard !email.hasPrefix("error@") else { throw MockError.invalidCredentials }
        if requiresEmailConfirmation { return .needsEmailConfirmation }
        setSession(UUID(), email: email)
        return .signedIn
    }

    func sendPasswordReset(email: String) async throws {
        lastPasswordResetEmail = email
    }

    func updatePassword(_ password: String) async throws {}

    func handle(_ url: URL) async throws -> AuthLink? {
        guard url.scheme == AuthRedirect.scheme else { return nil }
        if currentUserId == nil { setSession(UUID(), email: "link@mybasics.app") }
        return url.host == AuthRedirect.passwordReset.host ? .passwordRecovery : .emailConfirmed
    }

    func signOut() async throws {
        setSession(nil, email: nil)
    }

    func deleteAccount() async throws {
        deletedAccounts += 1
        setSession(nil, email: nil)
    }
}
