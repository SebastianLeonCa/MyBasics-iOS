import Foundation

nonisolated struct Expense: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var categoryId: UUID
    /// Monto en centavos. Nunca Double.
    var amountCents: Int
    /// Código ISO 4217, p. ej. "USD".
    var currency: String
    var kind: ExpenseKind
    var note: String?
    var spentAt: Date
    /// Categoría embebida (viene de la consulta anidada `category:categories(...)`).
    var category: Category?
    var debts: [Debt]

    init(
        id: UUID = UUID(),
        categoryId: UUID,
        amountCents: Int,
        currency: String = "USD",
        kind: ExpenseKind = .variable,
        note: String? = nil,
        spentAt: Date = .now,
        category: Category? = nil,
        debts: [Debt] = []
    ) {
        self.id = id
        self.categoryId = categoryId
        self.amountCents = amountCents
        self.currency = currency
        self.kind = kind
        self.note = note
        self.spentAt = spentAt
        self.category = category
        self.debts = debts
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case amountCents = "amount_cents"
        case currency
        case kind
        case note
        case spentAt = "spent_at"
        case category
        case debts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        categoryId = try c.decode(UUID.self, forKey: .categoryId)
        amountCents = try c.decode(Int.self, forKey: .amountCents)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        kind = try c.decode(ExpenseKind.self, forKey: .kind)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        spentAt = try c.decode(Date.self, forKey: .spentAt)
        category = try c.decodeIfPresent(Category.self, forKey: .category)
        debts = try c.decodeIfPresent([Debt].self, forKey: .debts) ?? []
    }
}

nonisolated extension Expense {
    /// Texto a mostrar en la lista: la descripción o, si no hay, el nombre de la categoría.
    var displayTitle: String {
        if let note, !note.trimmingCharacters(in: .whitespaces).isEmpty { return note }
        return category?.displayName ?? String(localized: "Gasto")
    }

    var hasPendingDebt: Bool { debts.contains { !$0.isSettled } }
}
