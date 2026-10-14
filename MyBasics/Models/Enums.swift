import Foundation

/// Tipo de gasto: fijo (arriendo, suscripciones) o variable (día a día).
nonisolated enum ExpenseKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fixed
    case variable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: "Fijo"
        case .variable: "Variable"
        }
    }
}

/// Dirección de una deuda asociada a un gasto.
nonisolated enum DebtDirection: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case theyOweMe = "they_owe_me"
    case iOweThem = "i_owe_them"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theyOweMe: "Me deben"
        case .iOweThem: "Yo debo"
        }
    }
}
