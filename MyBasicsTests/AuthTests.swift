import XCTest
@testable import MyBasics

final class NonceAndGoogleTests: XCTestCase {
    func testPkceChallengeMatchesRfc7636() {
        // RFC 7636, Apéndice B.
        XCTAssertEqual(
            Nonce.pkceChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testNonceIsRandomAndHashIsSha256Hex() {
        let a = Nonce.random(), b = Nonce.random()
        XCTAssertEqual(a.count, 32)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Nonce.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testGoogleRequestUsesReversedClientIdAndHashedNonce() throws {
        let google = GoogleOAuthClient(clientID: "1234-abc.apps.googleusercontent.com")
        XCTAssertEqual(google.callbackScheme, "com.googleusercontent.apps.1234-abc")
        XCTAssertEqual(google.redirectURI, "com.googleusercontent.apps.1234-abc:/oauth2redirect")

        let request = google.makeRequest()
        let items = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        XCTAssertEqual(value("code_challenge_method"), "S256")
        XCTAssertEqual(value("code_challenge"), Nonce.pkceChallenge(for: request.codeVerifier))
        XCTAssertEqual(value("nonce"), Nonce.sha256(request.rawNonce), "a Google va el hash; a Supabase, el original")
        XCTAssertEqual(value("state"), request.state)
        XCTAssertEqual(value("scope"), "openid email profile")
    }

    func testGoogleCallbackWithWrongStateIsRejected() async {
        let google = GoogleOAuthClient(clientID: "1234-abc.apps.googleusercontent.com")
        let request = google.makeRequest()
        let callback = URL(string: "com.googleusercontent.apps.1234-abc:/oauth2redirect?code=x&state=otro")!
        do {
            _ = try await google.tokens(from: callback, for: request)
            XCTFail("debía fallar")
        } catch let error as GoogleOAuthClient.GoogleError {
            guard case .stateMismatch = error else { return XCTFail("error inesperado: \(error)") }
        } catch {
            XCTFail("error inesperado: \(error)")
        }
    }
}

@MainActor
final class LoginViewModelTests: XCTestCase {
    func testValidation() {
        let vm = LoginViewModel(auth: MockAuthService(signedIn: false), googleClientID: nil)
        XCTAssertFalse(vm.canSubmit)
        vm.email = "  Ana@Example.com "
        vm.password = "1234567"
        XCTAssertTrue(vm.isEmailValid)
        XCTAssertEqual(vm.trimmedEmail, "ana@example.com")
        XCTAssertFalse(vm.canSubmit, "contraseña muy corta")
        vm.password = "12345678"
        XCTAssertTrue(vm.canSubmit)
        for bad in ["ana", "ana@", "ana@example", "ana@example.", "a na@x.com"] {
            vm.email = bad
            XCTAssertFalse(vm.isEmailValid, bad)
        }
        XCTAssertFalse(vm.isGoogleConfigured)
    }

    func testSignInCallsBackAndErrorsAreShown() async {
        let auth = MockAuthService(signedIn: false)
        var signedIn = 0
        let vm = LoginViewModel(auth: auth, googleClientID: nil, onSignedIn: { signedIn += 1 })
        vm.email = "error@example.com"
        vm.password = "12345678"
        await vm.submit()
        XCTAssertNotNil(vm.alert)
        XCTAssertEqual(signedIn, 0)

        vm.alert = nil
        vm.email = "ana@example.com"
        await vm.submit()
        XCTAssertNil(vm.alert)
        XCTAssertEqual(signedIn, 1)
        XCTAssertEqual(auth.currentUserEmail, "ana@example.com")
    }

    func testSignUpWithEmailConfirmationShowsMessage() async {
        let auth = MockAuthService(signedIn: false)
        auth.requiresEmailConfirmation = true
        let vm = LoginViewModel(auth: auth, googleClientID: "1-a.apps.googleusercontent.com")
        vm.mode = .signUp
        vm.email = "nuevo@example.com"
        vm.password = "12345678"
        await vm.submit()
        XCTAssertNotNil(vm.infoMessage)
        XCTAssertEqual(vm.mode, .signIn, "vuelve a Iniciar sesión para cuando confirme")
        XCTAssertTrue(vm.password.isEmpty)
        XCTAssertNil(auth.currentUserId)
        XCTAssertTrue(vm.isGoogleConfigured)
    }

    func testPasswordResetNeedsEmail() async {
        let auth = MockAuthService(signedIn: false)
        let vm = LoginViewModel(auth: auth, googleClientID: nil)
        await vm.sendPasswordReset()
        XCTAssertNotNil(vm.alert)
        XCTAssertNil(auth.lastPasswordResetEmail)

        vm.email = "ana@example.com"
        await vm.sendPasswordReset()
        XCTAssertEqual(auth.lastPasswordResetEmail, "ana@example.com")
        XCTAssertNotNil(vm.infoMessage)
    }
}

@MainActor
final class SessionTests: XCTestCase {
    private func makeEnvironment(signedIn: Bool) -> (AppEnvironment, MockAuthService, InMemoryExpenseCache) {
        let auth = MockAuthService(signedIn: signedIn)
        let cache = InMemoryExpenseCache()
        let env = AppEnvironment(
            expenseRepository: MockExpenseRepository(),
            categoryRepository: MockCategoryRepository(),
            authService: auth,
            dataSource: .mock,
            expenseCache: cache)
        return (env, auth, cache)
    }

    func testStartRestoresSessionOrShowsLogin() async {
        let (signedIn, _, _) = makeEnvironment(signedIn: true)
        XCTAssertEqual(signedIn.sessionState, .loading)
        await signedIn.start()
        XCTAssertEqual(signedIn.sessionState, .signedIn(MockAuthService.developmentUserId))

        let (signedOut, _, _) = makeEnvironment(signedIn: false)
        await signedOut.start()
        XCTAssertEqual(signedOut.sessionState, .signedOut)
    }

    func testSignOutAndDeleteAccountClearCacheAndShowLogin() async throws {
        let (env, auth, cache) = makeEnvironment(signedIn: true)
        await env.start()
        let user = MockAuthService.developmentUserId
        cache.store([], for: .now, userId: user)

        try await env.signOut()
        XCTAssertEqual(env.sessionState, .signedOut)
        XCTAssertNil(cache.expenses(for: .now, userId: user))

        try await auth.signIn(email: "ana@example.com", password: "12345678")
        env.syncSession()
        XCTAssertEqual(env.sessionState, .signedIn(user))
        cache.store([], for: .now, userId: user)

        try await env.deleteAccount()
        XCTAssertEqual(auth.deletedAccounts, 1)
        XCTAssertEqual(env.sessionState, .signedOut)
        XCTAssertNil(cache.expenses(for: .now, userId: user))
    }

    func testAuthEventsDriveTheSession() async throws {
        let (env, auth, _) = makeEnvironment(signedIn: false)
        await env.start()
        try await auth.signInWithApple(idToken: "t", rawNonce: "n", fullName: nil)
        let appleUser = try XCTUnwrap(auth.currentUserId)
        await waitUntil { env.sessionState == .signedIn(appleUser) }
        XCTAssertEqual(env.sessionState, .signedIn(appleUser), "un evento signedIn abre la app")

        try await auth.signOut()
        await waitUntil { env.sessionState == .signedOut }
        XCTAssertEqual(env.sessionState, .signedOut, "un evento signedOut (p. ej. sesión expirada) vuelve al login")
    }

    func testPasswordResetLinkOpensNewPasswordSheet() async {
        let (env, _, _) = makeEnvironment(signedIn: false)
        await env.start()
        await env.handleOpenURL(URL(string: "mybasics://reset-password?code=abc")!)
        XCTAssertTrue(env.isRecoveringPassword)
        XCTAssertNotEqual(env.sessionState, .signedOut)

        let (other, _, _) = makeEnvironment(signedIn: false)
        await other.start()
        await other.handleOpenURL(URL(string: "mybasics://auth-callback?code=abc")!)
        XCTAssertFalse(other.isRecoveringPassword)
        XCTAssertNotNil(other.linkMessage, "avisa que el correo quedó confirmado")

        await other.handleOpenURL(URL(string: "https://example.com")!)
        XCTAssertFalse(other.isRecoveringPassword, "enlaces ajenos se ignoran")
    }

    /// Los eventos llegan por un AsyncStream: damos unas vueltas al run loop.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<50 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
