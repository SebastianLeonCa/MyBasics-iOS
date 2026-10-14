import Foundation

/// Valores de conexión leídos del Info.plist (que a su vez los toma de Config/Secrets.xcconfig).
/// Nada de esto se escribe en el código ni se sube a Git.
nonisolated struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String
    /// Usuario de prueba de la Fase 2 (inicio de sesión silencioso). Se elimina en la Fase 4.
    let devUserEmail: String
    let devUserPassword: String

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
              let anonKey = value("SupabaseAnonKey"),
              let email = value("DevUserEmail"),
              let password = value("DevUserPassword")
        else { return nil }

        return SupabaseConfig(url: url, anonKey: anonKey, devUserEmail: email, devUserPassword: password)
    }
}
