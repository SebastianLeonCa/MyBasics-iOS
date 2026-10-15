import Foundation
import Supabase

final class SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    private struct CurrencyRow: Codable, Sendable {
        let currency: String
    }

    private struct ProfileUpsert: Encodable, Sendable {
        let user_id: UUID
        let currency: String
        let updated_at: String
    }

    func fetchCurrency() async throws -> String? {
        // RLS devuelve solo la fila del usuario actual.
        let rows: [CurrencyRow] = try await client
            .from("profiles")
            .select("currency")
            .limit(1)
            .execute()
            .value
        return rows.first?.currency
    }

    func updateCurrency(_ currency: String) async throws {
        guard let userId = client.auth.currentUser?.id else { throw RepositoryError.notAuthenticated }
        // Upsert: funciona aunque el perfil no exista todavía.
        try await client
            .from("profiles")
            .upsert(
                ProfileUpsert(user_id: userId, currency: currency, updated_at: JSONCoding.iso8601String(.now)),
                onConflict: "user_id",
                returning: .minimal)
            .execute()
    }
}
