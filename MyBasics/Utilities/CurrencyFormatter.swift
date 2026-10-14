import Foundation

/// Formatea y parsea montos. El dinero SIEMPRE viaja como `Int` en centavos;
/// solo se convierte a `Decimal` en el momento de mostrar o leer lo que escribe el usuario.
/// Los separadores (miles/decimales) siguen el idioma y región del dispositivo.
enum CurrencyFormatter {
    static let defaultCurrency = "USD"

    /// Centavos por unidad. Fijo en 100 para todas las monedas: $4,500.00 = 450000.
    static let centsPerUnit = 100
    /// Máximo de decimales que se aceptan al escribir un monto.
    static let maxInputDecimals = 2

    private static var cache: [String: NumberFormatter] = [:]

    private static func formatter(for currency: String, locale: Locale) -> NumberFormatter {
        let key = "\(currency)|\(locale.identifier)"
        if let cached = cache[key] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        f.currencyCode = currency
        cache[key] = f
        return f
    }

    /// Decimales que admite la moneda al escribir (USD = 2, CLP = 0), con tope de 2.
    static func inputDecimals(for currency: String, locale: Locale = .current) -> Int {
        min(formatter(for: currency, locale: locale).maximumFractionDigits, maxInputDecimals)
    }

    /// Separador decimal del dispositivo ("." en inglés/EE.UU., "," en España/Chile).
    static func decimalSeparator(locale: Locale = .current) -> String {
        locale.decimalSeparator ?? "."
    }

    /// Símbolo de la moneda ("$" para USD en EE.UU., "US$" en otras regiones).
    static func symbol(for currency: String, locale: Locale = .current) -> String {
        formatter(for: currency, locale: locale).currencySymbol ?? currency
    }

    /// 450000 centavos USD → "$4,500.00" (en_US) o "4.500,00 US$" (es_ES).
    static func string(fromCents cents: Int, currency: String = defaultCurrency, locale: Locale = .current) -> String {
        let value = Decimal(cents) / Decimal(centsPerUnit)
        return formatter(for: currency, locale: locale).string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Limpia lo que se escribe en un campo de monto: solo dígitos, un separador decimal
    /// y como máximo los decimales permitidos. "45.678" → "45.67"; "1.2.3" → "1.23".
    static func sanitizeInput(_ input: String, currency: String = defaultCurrency, locale: Locale = .current) -> String {
        let separator = Character(decimalSeparator(locale: locale))
        let decimals = inputDecimals(for: currency, locale: locale)
        var integer = ""
        var fraction = ""
        var seenSeparator = false

        for ch in input {
            if ch.isASCII, ch.isNumber {
                if seenSeparator {
                    if fraction.count < decimals { fraction.append(ch) }
                } else if integer.count < 9 {   // tope razonable: < 1.000 millones
                    integer.append(ch)
                }
            } else if ch == separator, decimals > 0, !seenSeparator {
                seenSeparator = true
            }
            // Cualquier otro carácter (letras, separador de miles, un 2.º separador) se descarta.
        }

        // Quita ceros a la izquierda ("007" → "7"), pero deja "0" antes del separador.
        while integer.count > 1, integer.first == "0" { integer.removeFirst() }
        if seenSeparator && integer.isEmpty { integer = "0" }
        return seenSeparator ? integer + String(separator) + fraction : integer
    }

    /// Lo que escribe el usuario → centavos. "4500" → 450000, "12.5" → 1250 (en_US).
    /// Devuelve nil si no hay un número válido o tiene más decimales de los permitidos.
    static func cents(fromInput input: String, currency: String = defaultCurrency, locale: Locale = .current) -> Int? {
        let separator = Character(decimalSeparator(locale: locale))
        let decimals = inputDecimals(for: currency, locale: locale)
        let parts = input.filter { $0.isASCII && $0.isNumber || $0 == separator }.split(
            separator: separator, maxSplits: 2, omittingEmptySubsequences: false)

        guard parts.count <= 2 else { return nil }
        let integerPart = parts.first.map(String.init) ?? ""
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        guard !integerPart.isEmpty || !fractionPart.isEmpty, fractionPart.count <= decimals else { return nil }

        let paddedFraction = fractionPart.padding(toLength: 2, withPad: "0", startingAt: 0)
        guard let units = Int(integerPart.isEmpty ? "0" : integerPart),
              let fraction = Int(paddedFraction) else { return nil }

        let (scaled, overflow) = units.multipliedReportingOverflow(by: centsPerUnit)
        guard !overflow else { return nil }
        return scaled + fraction
    }

    /// Centavos → texto editable para un campo de monto: 125000 → "1250", 1250 → "12.50" (en_US).
    static func inputString(fromCents cents: Int, currency: String = defaultCurrency, locale: Locale = .current) -> String {
        let units = cents / centsPerUnit
        let remainder = abs(cents % centsPerUnit)
        guard inputDecimals(for: currency, locale: locale) > 0, remainder != 0 else { return "\(units)" }
        return "\(units)\(decimalSeparator(locale: locale))\(String(format: "%02d", remainder))"
    }

    /// Redondea a la unidad mínima que se puede escribir (CLP: pesos enteros; USD: centavos).
    static func roundedToInputable(_ cents: Int, currency: String = defaultCurrency, locale: Locale = .current) -> Int {
        guard inputDecimals(for: currency, locale: locale) == 0 else { return cents }
        return ((cents + centsPerUnit / 2) / centsPerUnit) * centsPerUnit
    }
}
