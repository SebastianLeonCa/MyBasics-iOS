import Foundation

/// Sesión del usuario. En Fases 0–3 es mock; la autenticación real llega en la Fase 4.
protocol AuthService: AnyObject {
    var currentUserId: UUID? { get }
    var isSignedIn: Bool { get }
    func signIn() async throws
    func signOut() async throws
}

extension AuthService {
    var isSignedIn: Bool { currentUserId != nil }
}
