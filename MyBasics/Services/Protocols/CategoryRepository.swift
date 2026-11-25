import Foundation

protocol CategoryRepository: AnyObject {
    func fetchCategories() async throws -> [Category]
    func create(_ category: Category) async throws -> Category
}
