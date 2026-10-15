import Foundation

@Observable
final class AddExpenseViewModel {
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
    var hasDebt = false
    var debtPerson = ""
    /// Solo se usa con "Me debe": cuánto de lo que pagaste te van a devolver.
    /// Vacío = se usa la sugerencia (la mitad), que se ve en gris. Lo que escribas queda fijo:
    /// cambiar el total después no lo modifica.
    private(set) var debtAmountText = ""
    var debtDirection: DebtDirection = .theyOweMe

    private(set) var isLoadingCategories = false
    /// Error al cargar las categorías (se muestra en la fila de chips con "Reintentar").
    private(set) var categoriesError: String?
    var alert: UserFacingError?

    init(
        editing expense: Expense? = nil,
        categoryRepository: any CategoryRepository,
        currency: String
    ) {
        self.editingExpense = expense
        self.categoryRepository = categoryRepository
        self.currency = currency

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
            }
        }
    }

    // MARK: - Derivados

    var isEditing: Bool { editingExpense != nil }
    var title: String { isEditing ? String(localized: "Editar gasto") : String(localized: "Nuevo gasto") }
    var usesDecimals: Bool { CurrencyFormatter.inputDecimals(for: currency) > 0 }
    var selectedCategory: Category? { categories.first { $0.id == categoryId } }

    var amountCents: Int? {
        if let original = editingExpense, amountText == originalAmountText { return original.amountCents }
        return CurrencyFormatter.cents(fromInput: amountText, currency: currency)
    }

    /// Texto con el que se precargó el monto al editar (para saber si se tocó).
    private var originalAmountText: String? {
        editingExpense.map { CurrencyFormatter.inputString(fromCents: $0.amountCents, currency: currency) }
    }
    /// Sugerencia para "Me debe": la mitad del total (redondeada a lo que se puede escribir).
    var suggestedDebtCents: Int? {
        amountCents.map { CurrencyFormatter.roundedToInputable($0 / 2, currency: currency) }
    }

    /// true si el monto de "Me debe" es la sugerencia (nadie escribió uno).
    var isUsingSuggestedDebt: Bool { debtAmountText.isEmpty }

    /// Si este compartido ya estaba marcado como pagado (al editar).
    var isDebtSettled: Bool { editingExpense?.debts.first?.isSettled == true }

    /// "Me debe": el monto que escribiste, o la sugerencia (la mitad) si lo dejaste vacío.
    /// "Le debo": el gasto completo. Registras solo tu parte y eso es lo que debes; no se pide otro monto.
    var debtAmountCents: Int? {
        switch debtDirection {
        case .theyOweMe:
            if let debt = editingExpense?.debts.first, debt.direction == .theyOweMe,
               debtAmountText == CurrencyFormatter.inputString(fromCents: debt.amountCents, currency: currency) {
                return debt.amountCents   // no lo tocaste: se conserva exacto
            }
            return debtAmountText.isEmpty
                ? suggestedDebtCents
                : CurrencyFormatter.cents(fromInput: debtAmountText, currency: currency)
        case .iOweThem:
            return amountCents
        }
    }

    /// Con "Me debe": tu parte, lo que te cuesta el gasto una vez que te paguen (total − lo que te deben).
    var netAfterReimbursementCents: Int? {
        guard debtDirection == .theyOweMe, let amount = amountCents, let debt = debtAmountCents else { return nil }
        return max(amount - debt, 0)
    }

    var isDebtValid: Bool {
        guard hasDebt else { return true }
        guard let debt = debtAmountCents, let amount = amountCents else { return false }
        return !debtPerson.trimmingCharacters(in: .whitespaces).isEmpty && debt > 0 && debt <= amount
    }

    var canSave: Bool {
        (amountCents ?? 0) > 0 && categoryId != nil && isDebtValid
    }

    // MARK: - Acciones

    func setAmountText(_ text: String) {
        amountText = CurrencyFormatter.sanitizeInput(text, currency: currency)
    }

    func setDebtAmountText(_ text: String) {
        debtAmountText = CurrencyFormatter.sanitizeInput(text, currency: currency)
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categories = try await categoryRepository.fetchCategories()
            categoriesError = nil
        } catch is CancellationError {
            return
        } catch {
            categoriesError = UserFacingError.describe(error)
        }
    }

    func addCategory(_ category: Category) async throws {
        let saved = try await categoryRepository.create(category)
        categories.append(saved)
        categoryId = saved.id
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
            kind: kind,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            spentAt: spentAt,
            category: categories.first { $0.id == categoryId } ?? editingExpense?.category,
            debts: debts
        )
    }
}
