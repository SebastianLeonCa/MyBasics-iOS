import Foundation

@Observable
final class AddExpenseViewModel {
    private let expenseRepository: any ExpenseRepository
    private let categoryRepository: any CategoryRepository
    let editingExpense: Expense?
    let currency: String

    /// Texto del campo de monto. Se escribe con `setAmountText(_:)`, que lo limpia.
    private(set) var amountText = ""
    private(set) var categories: [Category] = []
    var categoryId: UUID? {
        didSet {
            // Una suscripción es un gasto fijo por naturaleza.
            if categoryId != oldValue, selectedCategory?.isSubscriptions == true { kind = .fixed }
        }
    }
    var kind: ExpenseKind = .variable
    var note = ""
    var spentAt = Date.now

    // Gasto compartido (sección plegable: abierta = alguien me debe o yo le debo una parte)
    var hasDebt = false {
        didSet { if hasDebt { syncDebtAmountIfNeeded() } }
    }
    var debtPerson = ""
    private(set) var debtAmountText = ""
    var debtDirection: DebtDirection = .theyOweMe
    /// Si el usuario tocó el monto compartido, deja de seguir "la mitad del gasto".
    private var debtAmountEdited = false

    private(set) var isSaving = false
    var errorMessage: String?

    init(
        editing expense: Expense? = nil,
        expenseRepository: any ExpenseRepository,
        categoryRepository: any CategoryRepository,
        currency: String
    ) {
        self.editingExpense = expense
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.currency = expense?.currency ?? currency

        if let expense {
            amountText = CurrencyFormatter.inputString(fromCents: expense.amountCents, currency: self.currency)
            categoryId = expense.categoryId
            kind = expense.kind
            note = expense.note ?? ""
            spentAt = expense.spentAt
            if let debt = expense.debts.first {
                hasDebt = true
                debtPerson = debt.counterpartyName
                debtAmountText = CurrencyFormatter.inputString(fromCents: debt.amountCents, currency: self.currency)
                debtDirection = debt.direction
                debtAmountEdited = true
            }
        }
    }

    // MARK: - Derivados

    var isEditing: Bool { editingExpense != nil }
    var title: String { isEditing ? String(localized: "Editar gasto") : String(localized: "Nuevo gasto") }
    var usesDecimals: Bool { CurrencyFormatter.inputDecimals(for: currency) > 0 }
    var selectedCategory: Category? { categories.first { $0.id == categoryId } }

    var amountCents: Int? { CurrencyFormatter.cents(fromInput: amountText, currency: currency) }
    var debtAmountCents: Int? { CurrencyFormatter.cents(fromInput: debtAmountText, currency: currency) }

    var isDebtValid: Bool {
        guard hasDebt else { return true }
        guard let debt = debtAmountCents, let amount = amountCents else { return false }
        return !debtPerson.trimmingCharacters(in: .whitespaces).isEmpty && debt > 0 && debt <= amount
    }

    var canSave: Bool {
        (amountCents ?? 0) > 0 && categoryId != nil && isDebtValid && !isSaving
    }

    // MARK: - Acciones

    func setAmountText(_ text: String) {
        amountText = CurrencyFormatter.sanitizeInput(text, currency: currency)
        syncDebtAmountIfNeeded()
    }

    func setDebtAmountText(_ text: String) {
        debtAmountText = CurrencyFormatter.sanitizeInput(text, currency: currency)
        debtAmountEdited = true
    }

    func loadCategories() async {
        do {
            categories = try await categoryRepository.fetchCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCategory(_ category: Category) async throws {
        let saved = try await categoryRepository.create(category)
        categories.append(saved)
        categoryId = saved.id
    }

    /// Guarda (crea o actualiza). Devuelve el gasto guardado, o nil si falló.
    func save() async -> Expense? {
        guard canSave, let expense = makeExpense() else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            return isEditing
                ? try await expenseRepository.update(expense)
                : try await expenseRepository.create(expense)
        } catch {
            errorMessage = String(localized: "No se pudo guardar. \(error.localizedDescription)")
            return nil
        }
    }

    func makeExpense() -> Expense? {
        guard let amount = amountCents, amount > 0, let categoryId else { return nil }

        let existingDebts = editingExpense?.debts ?? []
        var debts: [Debt] = []
        if hasDebt, let debtAmount = debtAmountCents {
            var debt = existingDebts.first
                ?? Debt(counterpartyName: "", amountCents: debtAmount, direction: debtDirection)
            debt.counterpartyName = debtPerson.trimmingCharacters(in: .whitespaces)
            debt.amountCents = debtAmount
            debt.direction = debtDirection
            debts = [debt] + existingDebts.dropFirst()
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return Expense(
            id: editingExpense?.id ?? UUID(),
            categoryId: categoryId,
            amountCents: amount,
            currency: currency,
            kind: kind,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            spentAt: spentAt,
            category: categories.first { $0.id == categoryId } ?? editingExpense?.category,
            debts: debts
        )
    }

    private func syncDebtAmountIfNeeded() {
        guard !debtAmountEdited else { return }
        debtAmountText = amountCents.map {
            CurrencyFormatter.inputString(
                fromCents: CurrencyFormatter.roundedToInputable($0 / 2, currency: currency),
                currency: currency)
        } ?? ""
    }
}
