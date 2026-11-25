import Foundation

@Observable
final class CategoriesViewModel {
    private let repository: any CategoryRepository

    private(set) var categories: [Category] = []
    private(set) var hasLoaded = false
    private(set) var loadError: String?

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            categories = try await repository.fetchCategories()
            hasLoaded = true
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            loadError = UserFacingError.describe(error)
        }
    }

    func add(_ category: Category) async throws {
        let saved = try await repository.create(category)
        categories.append(saved)
    }
}
