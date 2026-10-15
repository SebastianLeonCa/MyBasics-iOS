import Foundation

/// Perfil del usuario: por ahora, solo la moneda (única fuente de verdad, en `profiles.currency`).
protocol ProfileRepository: AnyObject {
    /// nil si el usuario aún no tiene perfil.
    func fetchCurrency() async throws -> String?
    func updateCurrency(_ currency: String) async throws
}
