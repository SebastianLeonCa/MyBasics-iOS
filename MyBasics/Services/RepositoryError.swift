import Foundation

enum RepositoryError: LocalizedError {
    case notFound
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notFound: "No se encontró el registro."
        case .notAuthenticated: "Debes iniciar sesión."
        }
    }
}
