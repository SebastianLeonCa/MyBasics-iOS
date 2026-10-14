import Foundation

/// Formatea y parsea montos. El dinero SIEMPRE viaja como `Int` en centavos;
/// solo se convierte a `Decimal` en el momento de mostrar o leer lo que escribe el usuario.
enum CurrencyFormatter {
    static let defaultCurrency = "CLP"
    static let locale = Locale(identifier: "es_CL")

    /// Centavos por unidad. Fijo en 100 para todas las monedas: 2.500 CLP = 250000.
    static let centsPerUnit = 100

    private static var cache: [String: NumberFormatter] = [:]

    private static func formatter(for currency: String) -> NumberFormatter {
        if let cached = cache[currency] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        f.currencyCode = currency
        // CLP no usa decimales; NumberFormatter ya lo sabe por el código ISO.
        cache[currency] = f
        return f
    }

    /// Dígitos decimales que se muestran para la moneda (CLP = 0, USD = 2).
    static func fractionDigits(for currency: String) -> Int {
        formatter(for: currency).maximumFractionDigits
    }

    /// 250000 centavos CLP → "$2.500"
    static func string(fromCents cents: Int, currency: String = defaultCurrency) -> String {
        let value = Decimal(cents) / Decimal(centsPerUnit)
        return formatter(for: currency).string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Lo que escribe el usuario → centavos. "2.500" (CLP) → 250000, "12,5" (USD) → 1250.
    /// Devuelve nil si no hay un número válido.
    static func cents(fromInput input: String, currency: String = defaultCurrency) -> Int? {
        let digits = fractionDigits(for: currency)
        var integerPart = ""
        var fractionPart = ""
        var seenSeparator = false

        for ch in input {
            if ch.isASCII, ch.isNumber {
                if seenSeparator { fractionPart.append(ch) } else { integerPart.append(ch) }
            } else if ch == "," && digits > 0 {
                // En es_CL la coma es el separador decimal; el punto es de miles y se ignora.
                if seenSeparator { return nil }
                seenSeparator = true
            }
        }

        guard !integerPart.isEmpty || !fractionPart.isEmpty else { return nil }
        guard fractionPart.count <= digits else { return nil }

        let paddedFraction = fractionPart.padding(toLength: 2, withPad: "0", startingAt: 0)
        guard let units = Int(integerPart.isEmpty ? "0" : integerPart),
              let fraction = Int(paddedFraction) else { return nil }

        let (scaled, overflow) = units.multipliedReportingOverflow(by: centsPerUnit)
        guard !overflow else { return nil }
        return scaled + fraction
    }
}
