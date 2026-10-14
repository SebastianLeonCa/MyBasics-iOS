import Foundation
import Supabase

/// Error listo para mostrar en una alerta, con una acción opcional de reintento.
struct UserFacingError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let retry: (() async -> Void)?

    init(title: String = String(localized: "Algo salió mal"), message: String, retry: (() async -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retry = retry
    }

    init(_ error: Error, title: String = String(localized: "Algo salió mal"), retry: (() async -> Void)? = nil) {
        self.init(title: title, message: Self.describe(error), retry: retry)
    }

    /// Traduce errores técnicos a algo entendible.
    static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return String(localized: "Sin conexión a internet. Revisa tu conexión e inténtalo de nuevo.")
            case .timedOut:
                return String(localized: "El servidor tardó demasiado en responder.")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return String(localized: "No se pudo conectar con el servidor. Revisa SUPABASE_URL.")
            default:
                return urlError.localizedDescription
            }
        }
        if let postgrest = error as? PostgrestError {
            switch postgrest.code {
            case "23505": return String(localized: "Ya existe una categoría con ese nombre.")
            case "42501": return String(localized: "No tienes permiso para hacer esto.")
            case "P0002", "PGRST116": return String(localized: "No se encontró el registro.")
            case "PGRST202", "42P01", "42883":
                return String(localized: "La base de datos no está configurada. Ejecuta supabase/schema.sql en Supabase.")
            default: return postgrest.message
            }
        }
        if let auth = error as? AuthError {
            return String(localized: "No se pudo iniciar sesión con el usuario de prueba (\(auth.message)). Revisa DEV_USER_EMAIL y DEV_USER_PASSWORD.")
        }
        if error is DecodingError {
            return String(localized: "La respuesta del servidor no tiene el formato esperado.")
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
