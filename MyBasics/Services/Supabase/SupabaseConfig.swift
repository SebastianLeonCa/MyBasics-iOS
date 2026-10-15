import Foundation

/// Valores de conexión leídos del Info.plist (que a su vez los toma de Config/Secrets.xcconfig).
/// Nada de esto se escribe en el código ni se sube a Git.
nonisolated struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String
    /// OAuth client ID de Google (tipo iOS). nil = el botón avisa que falta configurarlo.
    let googleIOSClientID: String?

    /// APPLE_SIGN_IN = YES en Secrets.xcconfig (requiere el Apple Developer Program).
    static func isAppleSignInEnabled(_ bundle: Bundle = .main) -> Bool {
        (bundle.object(forInfoDictionaryKey: "AppleSignInEnabled") as? String)?.uppercased() == "YES"
    }

    /// nil si falta algún valor o siguen los placeholders de Secrets.example.xcconfig.
    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig? {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let isPlaceholder = trimmed.isEmpty || trimmed.contains("$(") || trimmed.hasPrefix("TU_")
                || trimmed.contains("TU-PROYECTO")
            return isPlaceholder ? nil : trimmed
        }

        guard let urlString = value("SupabaseURL"),
              let url = URL(string: urlString), url.scheme == "https", url.host != nil,
              let anonKey = value("SupabaseAnonKey")
        else { return nil }

        let google = value("GoogleIOSClientID").flatMap { $0.hasSuffix(".apps.googleusercontent.com") ? $0 : nil }
        return SupabaseConfig(url: url, anonKey: anonKey, googleIOSClientID: google)
    }
}
