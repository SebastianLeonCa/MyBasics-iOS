import AuthenticationServices
import Foundation

@Observable
final class LoginViewModel {
    enum Mode { case signIn, signUp }

    private let auth: any AuthService
    private let google: GoogleOAuthClient?
    /// Avisa a la app que ya hay sesión (además del flujo de eventos).
    private let onSignedIn: () -> Void

    var mode: Mode = .signIn {
        didSet { infoMessage = nil }
    }
    var email = ""
    var password = ""
    private(set) var isWorking = false
    /// Mensaje informativo (no error): "Te enviamos un correo…".
    private(set) var infoMessage: String?
    var alert: UserFacingError?
    private var appleRawNonce: String?

    static let minimumPasswordLength = 8

    init(auth: any AuthService, googleClientID: String?, onSignedIn: @escaping () -> Void = {}) {
        self.auth = auth
        self.google = googleClientID.map { GoogleOAuthClient(clientID: $0) }
        self.onSignedIn = onSignedIn
    }

    var supportsGoogle: Bool { google != nil }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var isEmailValid: Bool {
        let parts = trimmedEmail.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !parts[1].hasSuffix(".") && !trimmedEmail.contains(" ")
    }

    var isPasswordValid: Bool { password.count >= Self.minimumPasswordLength }
    var canSubmit: Bool { isEmailValid && isPasswordValid && !isWorking }

    // MARK: - Email

    func submit() async {
        guard canSubmit else { return }
        await perform {
            switch mode {
            case .signIn:
                try await auth.signIn(email: trimmedEmail, password: password)
                onSignedIn()
            case .signUp:
                switch try await auth.signUp(email: trimmedEmail, password: password) {
                case .signedIn:
                    onSignedIn()
                case .needsEmailConfirmation:
                    password = ""
                    mode = .signIn
                    infoMessage = String(localized: "Te enviamos un correo a \(trimmedEmail). Toca el enlace para activar tu cuenta y luego inicia sesión.")
                }
            }
        }
    }

    func sendPasswordReset() async {
        guard isEmailValid else {
            alert = UserFacingError(message: String(localized: "Escribe tu email arriba y vuelve a tocar “¿Olvidaste tu contraseña?”."))
            return
        }
        await perform {
            try await auth.sendPasswordReset(email: trimmedEmail)
            infoMessage = String(localized: "Si existe una cuenta con \(trimmedEmail), te llegará un correo para crear una contraseña nueva.")
        }
    }

    // MARK: - Apple

    /// Configura la petición de SignInWithAppleButton (nonce + datos solicitados).
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let raw = Nonce.random()
        appleRawNonce = raw
        request.requestedScopes = [.fullName, .email]
        request.nonce = Nonce.sha256(raw)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }   // la persona cerró la hoja
            alert = UserFacingError(error, title: String(localized: "No se pudo iniciar sesión con Apple"))
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = appleRawNonce
            else {
                alert = UserFacingError(message: String(localized: "Apple no devolvió una credencial válida."))
                return
            }
            await perform {
                try await auth.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: credential.fullName)
                onSignedIn()
            }
        }
    }

    // MARK: - Google

    /// `authenticate` abre la hoja web del sistema (WebAuthenticationSession de SwiftUI) y devuelve la URL de vuelta.
    func signInWithGoogle(authenticate: (URL, String) async throws -> URL) async {
        guard let google else { return }
        let request = google.makeRequest()
        do {
            let callback = try await authenticate(request.url, google.callbackScheme)
            await perform {
                let tokens = try await google.tokens(from: callback, for: request)
                try await auth.signInWithGoogle(
                    idToken: tokens.idToken, accessToken: tokens.accessToken, rawNonce: tokens.rawNonce)
                onSignedIn()
            }
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
            alert = UserFacingError(error, title: String(localized: "No se pudo iniciar sesión con Google"))
        }
    }

    // MARK: -

    private func perform(_ work: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
        } catch {
            alert = UserFacingError(error, title: String(localized: "No se pudo continuar"))
        }
    }
}
