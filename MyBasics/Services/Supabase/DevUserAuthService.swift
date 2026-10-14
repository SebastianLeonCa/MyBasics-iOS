import Foundation
import Supabase

/// AuthService TEMPORAL de la Fase 2: inicia sesión en silencio con el usuario de prueba
/// (DEV_USER_EMAIL / DEV_USER_PASSWORD de Secrets.xcconfig) para que RLS funcione.
/// En la Fase 4 se reemplaza por SupabaseAuthService con login real.
final class DevUserAuthService: AuthService {
    private let client: SupabaseClient
    private let email: String
    private let password: String

    init(client: SupabaseClient, email: String, password: String) {
        self.client = client
        self.email = email
        self.password = password
    }

    var currentUserId: UUID? { client.auth.currentUser?.id }

    func signIn() async throws {
        // Reusa la sesión guardada en el Keychain (la refresca si venció); si no hay, entra con el usuario de prueba.
        if let session = try? await client.auth.session, session.user.email?.lowercased() == email.lowercased() {
            return
        }
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
