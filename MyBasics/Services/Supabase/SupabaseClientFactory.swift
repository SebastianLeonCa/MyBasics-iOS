import Foundation
import Supabase

nonisolated enum SupabaseClientFactory {
    static func make(_ config: SupabaseConfig) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                db: .init(encoder: JSONCoding.makeEncoder(), decoder: JSONCoding.makeDecoder()),
                // La sesión se guarda en el Keychain (default del SDK en iOS).
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
