import Foundation

final class MockCategoryRepository: CategoryRepository {
    private(set) var categories: [Category]

    init(categories: [Category] = Category.defaults) {
        self.categories = categories
    }

    func fetchCategories() async throws -> [Category] {
        categories
    }

    func create(_ category: Category) async throws -> Category {
        categories.append(category)
        return category
    }
}
