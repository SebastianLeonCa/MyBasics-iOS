import Foundation

/// Monedas que se pueden elegir en Ajustes.
nonisolated enum CurrencyOptions {
    static let codes = ["USD", "EUR", "MXN", "COP", "PEN", "CLP", "ARS", "BRL", "GBP", "CAD"]

    /// "Dólar estadounidense (USD)" en el idioma del dispositivo.
    static func displayName(for code: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(name.prefix(1).uppercased(with: locale) + name.dropFirst()) (\(code))"
    }
}
