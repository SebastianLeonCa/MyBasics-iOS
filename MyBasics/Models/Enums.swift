import Foundation

/// Tipo de gasto: fijo (arriendo, suscripciones) o variable (día a día).
nonisolated enum ExpenseKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fixed
    case variable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: String(localized: "Fijo")
        case .variable: String(localized: "Variable")
        }
    }
}

/// Dirección de un gasto compartido (en la base de datos se llama "debt").
nonisolated enum DebtDirection: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case theyOweMe = "they_owe_me"
    case iOweThem = "i_owe_them"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theyOweMe: String(localized: "Me debe")
        case .iOweThem: String(localized: "Le debo")
        }
    }
}
