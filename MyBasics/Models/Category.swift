import Foundation

nonisolated struct Category: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
    /// Nombre de un SF Symbol.
    var icon: String
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, colorHex: String, icon: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.isDefault = isDefault
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex = "color_hex"
        case icon
        case isDefault = "is_default"
    }

    // La API puede embeber la categoría con solo algunos campos
    // (p. ej. name, color_hex, icon), así que los opcionales tienen default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#8E8E93"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "tag"
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

nonisolated extension Category {
    /// Nombre (en español) con el que se guarda la categoría de suscripciones por defecto.
    static let subscriptionsName = "Suscripciones"

    /// Nombre para mostrar: las categorías por defecto se traducen; las creadas por el usuario no.
    var displayName: String {
        isDefault ? Bundle.main.localizedString(forKey: name, value: name, table: nil) : name
    }

    var isSubscriptions: Bool { isDefault && name == Self.subscriptionsName }

    /// Categorías por defecto (las mismas que sembrará Supabase en la Fase 2).
    /// Se guardan en español; `displayName` las traduce.
    static let defaults: [Category] = [
        Category(name: "Comida", colorHex: "#FF6B35", icon: "fork.knife", isDefault: true),
        Category(name: "Supermercado", colorHex: "#2EC4B6", icon: "cart", isDefault: true),
        Category(name: "Transporte", colorHex: "#3A86FF", icon: "car", isDefault: true),
        Category(name: "Hogar", colorHex: "#8338EC", icon: "house", isDefault: true),
        Category(name: subscriptionsName, colorHex: "#5E60CE", icon: "repeat", isDefault: true),
        Category(name: "Salud", colorHex: "#FF006E", icon: "cross.case", isDefault: true),
        Category(name: "Ocio", colorHex: "#FFBE0B", icon: "gamecontroller", isDefault: true),
        Category(name: "Otros", colorHex: "#8E8E93", icon: "ellipsis.circle", isDefault: true),
    ]
}
