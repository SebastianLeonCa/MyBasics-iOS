import Foundation

/// "Continuar con Google" sin SDK de terceros: OAuth 2.0 con PKCE en una hoja web del sistema
/// (ASWebAuthenticationSession, vía `WebAuthenticationSession` de SwiftUI). Devuelve el ID token
/// de Google, que luego se entrega a Supabase con `signInWithIdToken`.
nonisolated struct GoogleOAuthClient: Sendable {
    struct Tokens: Sendable {
        let idToken: String
        let accessToken: String
        let rawNonce: String
    }

    enum GoogleError: LocalizedError {
        case invalidCallback, stateMismatch, missingToken
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidCallback, .stateMismatch, .missingToken:
                String(localized: "Google no devolvió una respuesta válida. Inténtalo de nuevo.")
            case .server(let message):
                message
            }
        }
    }

    /// Client ID de tipo iOS, p. ej. "1234-abc.apps.googleusercontent.com".
    let clientID: String
    var session: URLSession = .shared

    /// "com.googleusercontent.apps.1234-abc": esquema al que Google redirige (client ID invertido).
    var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    struct Request: Sendable {
        let url: URL
        let state: String
        let codeVerifier: String
        let rawNonce: String
    }

    func makeRequest() -> Request {
        let state = Nonce.random(length: 24)
        let verifier = Nonce.random(length: 64)
        let rawNonce = Nonce.random()
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: Nonce.pkceChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: Nonce.sha256(rawNonce)),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return Request(url: components.url!, state: state, codeVerifier: verifier, rawNonce: rawNonce)
    }

    /// Lee el `code` de la URL de vuelta y lo canjea por tokens.
    func tokens(from callback: URL, for request: Request) async throws -> Tokens {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") { throw GoogleError.server(error) }
        guard value("state") == request.state else { throw GoogleError.stateMismatch }
        guard let code = value("code") else { throw GoogleError.invalidCallback }

        var http = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        http.httpMethod = "POST"
        http.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: request.codeVerifier),
        ]
        http.httpBody = Data((body.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await session.data(for: http)
        struct TokenResponse: Decodable {
            let id_token: String?
            let access_token: String?
            let error_description: String?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GoogleError.server(decoded.error_description ?? String(localized: "Google rechazó el inicio de sesión."))
        }
        guard let idToken = decoded.id_token, let accessToken = decoded.access_token else {
            throw GoogleError.missingToken
        }
        return Tokens(idToken: idToken, accessToken: accessToken, rawNonce: request.rawNonce)
    }
}
