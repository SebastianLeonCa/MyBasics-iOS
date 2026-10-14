import Foundation

@Observable
final class CategoriesViewModel {
    private let repository: any CategoryRepository

    private(set) var categories: [Category] = []
    var errorMessage: String?

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            categories = try await repository.fetchCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(_ category: Category) async throws {
        let saved = try await repository.create(category)
        categories.append(saved)
    }
}
