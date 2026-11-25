import Foundation

nonisolated struct Debt: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var counterpartyName: String
    /// Monto en centavos. Nunca Double.
    var amountCents: Int
    var direction: DebtDirection
    var isSettled: Bool
    var settledAt: Date?

    init(
        id: UUID = UUID(),
        counterpartyName: String,
        amountCents: Int,
        direction: DebtDirection,
        isSettled: Bool = false,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.counterpartyName = counterpartyName
        self.amountCents = amountCents
        self.direction = direction
        self.isSettled = isSettled
        self.settledAt = settledAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case counterpartyName = "counterparty_name"
        case amountCents = "amount_cents"
        case direction
        case isSettled = "is_settled"
        case settledAt = "settled_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        counterpartyName = try c.decode(String.self, forKey: .counterpartyName)
        amountCents = try c.decode(Int.self, forKey: .amountCents)
        direction = try c.decode(DebtDirection.self, forKey: .direction)
        isSettled = try c.decodeIfPresent(Bool.self, forKey: .isSettled) ?? false
        settledAt = try c.decodeIfPresent(Date.self, forKey: .settledAt)
    }
}
