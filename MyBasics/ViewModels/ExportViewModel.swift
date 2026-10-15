import Foundation

@Observable
final class ExportViewModel {
    private let repository: any ExpenseRepository
    private let now: () -> Date

    private(set) var month: Date
    private(set) var expenses: [Expense] = []
    private(set) var fileURL: URL?
    private(set) var isLoading = false
    private(set) var loadError: String?

    init(repository: any ExpenseRepository, now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.now = now
        self.month = now().startOfMonth()
    }

    var monthTitle: String { month.monthTitle() }
    var canGoToNextMonth: Bool { month < now().startOfMonth() }
    var fileName: String { CSVExporter.fileName(for: month) }

    func showPreviousMonth() { month = month.addingMonths(-1); reset() }

    func showNextMonth() {
        guard canGoToNextMonth else { return }
        month = month.addingMonths(1)
        reset()
    }

    private func reset() {
        expenses = []
        fileURL = nil
        loadError = nil
    }

    /// Trae los gastos del mes y deja listo el archivo para compartir.
    func prepare(currency: String) async {
        let requested = month
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await repository.fetchExpenses(in: requested.monthInterval())
            guard requested == month else { return }
            expenses = result
            fileURL = result.isEmpty ? nil : try CSVExporter.writeFile(for: result, month: requested, currency: currency)
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            loadError = UserFacingError.describe(error)
        }
    }
}
