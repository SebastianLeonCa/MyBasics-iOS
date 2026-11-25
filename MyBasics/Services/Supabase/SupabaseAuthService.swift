import Foundation
import Supabase

/// Autenticación real con Supabase Auth. La sesión la guarda el SDK en el Keychain.
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUserId: UUID? { client.auth.currentUser?.id }
    var currentUserEmail: String? { client.auth.currentUser?.email }

    func events() -> AsyncStream<AuthEvent> {
        let client = client
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    case .signedOut, .userDeleted:
                        continuation.yield(.signedOut)
                    case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .passwordRecovery, .mfaChallengeVerified:
                        if let session { continuation.yield(.signedIn(session.user.id)) }
                    @unknown default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func restoreSession() async -> UUID? {
        // La sesión guardada se usa aunque el token haya vencido: el SDK lo renueva al primer uso.
        // Si la renovación falla para siempre (p. ej. se cerró sesión en otro lado), llega `.signedOut`.
        client.auth.currentSession?.user.id
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce))
        // Apple entrega el nombre solo la primera vez: lo guardamos en los metadatos del usuario.
        if let fullName {
            let name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
            if !name.isEmpty {
                _ = try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            }
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String, rawNonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google, idToken: idToken, accessToken: accessToken, nonce: rawNonce))
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws -> SignUpResult {
        let response = try await client.auth.signUp(
            email: email, password: password, redirectTo: AuthRedirect.emailConfirmation)
        switch response {
        case .session: return .signedIn
        case .user: return .needsEmailConfirmation
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: AuthRedirect.passwordReset)
    }

    func updatePassword(_ password: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: password))
    }

    func handle(_ url: URL) async throws -> AuthLink? {
        guard url.scheme == AuthRedirect.scheme else { return nil }
        _ = try await client.auth.session(from: url)
        return url.host == AuthRedirect.passwordReset.host ? .passwordRecovery : .emailConfirmed
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        // Borra auth.users (y en cascada sus datos) con la función SQL delete_my_account().
        try await client.rpc("delete_my_account").execute()
        // La sesión ya no es válida en el servidor: solo limpiamos la local.
        try? await client.auth.signOut(scope: .local)
    }
}
