import Foundation

final class MockAuthService: AuthService {
    static let developmentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private(set) var currentUserId: UUID?

    init(signedIn: Bool = true) {
        currentUserId = signedIn ? Self.developmentUserId : nil
    }

    func signIn() async throws {
        currentUserId = Self.developmentUserId
    }

    func signOut() async throws {
        currentUserId = nil
    }
}
