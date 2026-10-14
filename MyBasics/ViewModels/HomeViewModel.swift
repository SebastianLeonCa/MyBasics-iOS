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
    /// true cuando ya se cargó el mes actual al menos una vez.
    private(set) var hasLoaded = false
    /// Error de la carga del mes (se muestra en lugar de la lista, con "Reintentar").
    private(set) var loadError: String?
    /// Error de una acción (guardar, eliminar): se muestra como alerta.
    var alert: UserFacingError?

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
    /// Primera carga del mes en curso: se muestra un esqueleto.
    var isShowingSkeleton: Bool { !hasLoaded && loadError == nil }

    // MARK: - Navegación

    func showPreviousMonth() { changeMonth(by: -1) }

    func showNextMonth() {
        guard canGoToNextMonth else { return }
        changeMonth(by: 1)
    }

    private func changeMonth(by months: Int) {
        month = month.addingMonths(months)
        selectedCategoryId = nil
        // No mostramos datos del mes anterior bajo el título nuevo.
        expenses = []
        hasLoaded = false
        loadError = nil
    }

    func toggleSelection(_ categoryId: UUID?) {
        withAnimation(.snappy) {
            selectedCategoryId = (categoryId == selectedCategoryId) ? nil : categoryId
        }
    }

    // MARK: - Datos

    func load() async {
        let requested = month
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await repository.fetchExpenses(in: requested.monthInterval())
            guard requested == month else { return }   // el usuario ya cambió de mes
            withAnimation(.smooth) {
                expenses = result
                hasLoaded = true
                loadError = nil
                if selectedTotal == nil { selectedCategoryId = nil }
            }
        } catch is CancellationError {
            return
        } catch {
            guard requested == month else { return }
            if hasLoaded {
                // Ya hay datos en pantalla: los dejamos y avisamos.
                alert = UserFacingError(error, retry: { [weak self] in await self?.load() })
            } else {
                loadError = UserFacingError.describe(error)
            }
        }
    }

    /// Guardado optimista: se ve al instante; si el servidor falla, se revierte y se ofrece reintentar.
    func save(_ expense: Expense, isNew: Bool) async {
        let previous = expenses.first { $0.id == expense.id }
        applyLocally(expense)
        do {
            let saved = isNew ? try await repository.create(expense) : try await repository.update(expense)
            applyLocally(saved)   // versión del servidor (con la categoría embebida)
        } catch {
            withAnimation(.smooth) {
                expenses.removeAll { $0.id == expense.id }
                if let previous { expenses.append(previous) }
            }
            alert = UserFacingError(
                error,
                title: String(localized: "No se pudo guardar el gasto"),
                retry: { [weak self] in await self?.save(expense, isNew: isNew) })
        }
    }

    /// Eliminación optimista con rollback.
    func delete(_ expense: Expense) async {
        withAnimation(.smooth) {
            expenses.removeAll { $0.id == expense.id }
            if selectedTotal == nil { selectedCategoryId = nil }
        }
        do {
            try await repository.delete(id: expense.id)
        } catch {
            applyLocally(expense)
            alert = UserFacingError(
                error,
                title: String(localized: "No se pudo eliminar el gasto"),
                retry: { [weak self] in await self?.delete(expense) })
        }
    }

    /// Inserta/reemplaza en la lista si pertenece al mes visible (si no, lo quita).
    private func applyLocally(_ expense: Expense) {
        withAnimation(.smooth) {
            expenses.removeAll { $0.id == expense.id }
            if month.monthInterval().contains(expense.spentAt) {
                expenses.append(expense)
            }
            if selectedTotal == nil { selectedCategoryId = nil }
        }
    }
}
