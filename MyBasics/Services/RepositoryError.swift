import Foundation

enum RepositoryError: LocalizedError {
    case notFound
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notFound: String(localized: "No se encontró el registro.")
        case .notAuthenticated: String(localized: "Debes iniciar sesión.")
        }
    }
}
