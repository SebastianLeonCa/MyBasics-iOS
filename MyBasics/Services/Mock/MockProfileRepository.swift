import Foundation

final class MockProfileRepository: ProfileRepository {
    private(set) var currency: String?
    /// Para tests: hace fallar el guardado.
    var failUpdates = false

    init(currency: String? = CurrencyFormatter.defaultCurrency) {
        self.currency = currency
    }

    func fetchCurrency() async throws -> String? { currency }

    func updateCurrency(_ currency: String) async throws {
        if failUpdates { throw URLError(.notConnectedToInternet) }
        self.currency = currency
    }
}
