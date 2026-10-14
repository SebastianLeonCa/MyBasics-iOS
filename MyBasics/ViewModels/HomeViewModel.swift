import SwiftUI

@Observable
final class HomeViewModel {
    private let repository: any ExpenseRepository
    private let now: () -> Date

    /// Inicio del mes que se está mirando.
    private(set) var month: Date
    var filter: KindFilter = .all {
        didSet { selectedCategoryId = nil }
    }
    /// Categoría resaltada en el gráfico (nil = ninguna).
    private(set) var selectedCategoryId: UUID?
    private(set) var expenses: [Expense] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(repository: any ExpenseRepository, now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.now = now
        self.month = now().startOfMonth()
    }

    // MARK: - Derivados (todo sale de funciones puras de ExpenseAnalytics)

    var filteredExpenses: [Expense] { ExpenseAnalytics.filter(expenses, by: filter) }
    var categoryTotals: [CategoryTotal] { ExpenseAnalytics.categoryTotals(filteredExpenses) }
    var totalCents: Int { ExpenseAnalytics.total(filteredExpenses) }
    var daySections: [DaySection] { ExpenseAnalytics.groupByDay(filteredExpenses) }
    var selectedTotal: CategoryTotal? {
        guard let selectedCategoryId else { return nil }
        return categoryTotals.first { $0.categoryId == selectedCategoryId }
    }

    var monthTitle: String { month.monthTitle() }
    var canGoToNextMonth: Bool { month < now().startOfMonth() }

    // MARK: - Acciones

    func showPreviousMonth() {
        month = month.addingMonths(-1)
        selectedCategoryId = nil
    }

    func showNextMonth() {
        guard canGoToNextMonth else { return }
        month = month.addingMonths(1)
        selectedCategoryId = nil
    }

    func toggleSelection(_ categoryId: UUID?) {
        withAnimation(.snappy) {
            selectedCategoryId = (categoryId == selectedCategoryId) ? nil : categoryId
        }
    }

    func load() async {
        let requested = month
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await repository.fetchExpenses(in: requested.monthInterval())
            guard requested == month else { return }   // el usuario ya cambió de mes
            withAnimation(.smooth) {
                expenses = result
                if selectedTotal == nil { selectedCategoryId = nil }
            }
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refleja al instante un gasto recién creado o editado.
    func didSave(_ expense: Expense) {
        withAnimation(.smooth) {
            expenses.removeAll { $0.id == expense.id }
            if month.monthInterval().contains(expense.spentAt) {
                expenses.append(expense)
            }
            if selectedTotal == nil { selectedCategoryId = nil }
        }
    }

    /// Elimina de inmediato en pantalla; si el repositorio falla, se revierte.
    func delete(_ expense: Expense) async {
        let snapshot = expenses
        withAnimation(.smooth) {
            expenses.removeAll { $0.id == expense.id }
            if selectedTotal == nil { selectedCategoryId = nil }
        }
        do {
            try await repository.delete(id: expense.id)
        } catch {
            withAnimation(.smooth) { expenses = snapshot }
            errorMessage = "No se pudo eliminar el gasto. \(error.localizedDescription)"
        }
    }
}
