import Foundation
import Supabase

final class SupabaseCategoryRepository: CategoryRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchCategories() async throws -> [Category] {
        try await client
            .from("categories")
            .select(SupabaseQuery.categoryColumns)
            .order("created_at")
            .execute()
            .value
    }

    func create(_ category: Category) async throws -> Category {
        // user_id lo completa la base de datos con auth.uid().
        try await client
            .from("categories")
            .insert(CategoryInsert(category))
            .select(SupabaseQuery.categoryColumns)
            .single()
            .execute()
            .value
    }
}
