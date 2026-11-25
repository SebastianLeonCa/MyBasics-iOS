import Foundation

/// Formatea y parsea montos.
///
/// Estrategia (no cambia nunca la magnitud):
/// - El dinero SIEMPRE se guarda como `Int` en centésimos de la unidad (`amountCents`), para
///   todas las monedas: 5.000 = 500000. Cambiar de moneda no toca ese número.
/// - Al mostrar, se divide por 100 y se usan los decimales oficiales de la moneda (ISO 4217):
///   CLP 0 → "$5.000"; USD/PEN 2 → "$5,000.00" / "S/ 5,000.00". Si un monto tiene centavos y se
///   muestra en CLP, se redondea solo en pantalla (12,50 → "$13"); lo guardado no cambia.
/// - El símbolo sale de una tabla propia para que sea el mismo en cualquier idioma ("S/" y no
///   "PEN"); los separadores de miles y decimales siguen el idioma/región del dispositivo.
enum CurrencyFormatter {
    static let defaultCurrency = "USD"

    /// Centésimos por unidad. Fijo en 100 para todas las monedas.
    static let centsPerUnit = 100
    /// Máximo de decimales que se aceptan al escribir un monto.
    static let maxInputDecimals = 2

    /// Símbolos que se muestran (siempre delante del número).
    private static let symbols: [String: String] = [
        "USD": "$", "EUR": "€", "MXN": "$", "COP": "$", "PEN": "S/",
        "CLP": "$", "ARS": "$", "BRL": "R$", "GBP": "£", "CAD": "$",
    ]

    private static var digitsCache: [String: Int] = [:]

    /// Decimales oficiales de la moneda (ISO 4217): CLP 0, USD 2, PEN 2.
    static func fractionDigits(for currency: String) -> Int {
        if let cached = digitsCache[currency] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US_POSIX")
        f.currencyCode = currency
        let digits = f.maximumFractionDigits
        digitsCache[currency] = digits
        return digits
    }

    /// Decimales que se pueden escribir en esa moneda (CLP 0, USD 2), con tope de 2.
    static func inputDecimals(for currency: String) -> Int {
        min(fractionDigits(for: currency), maxInputDecimals)
    }

    /// Separador decimal del dispositivo ("." en inglés/EE.UU., "," en España/Chile).
    static func decimalSeparator(locale: Locale = .current) -> String {
        locale.decimalSeparator ?? "."
    }

    /// "S/", "$", "€"…; el código ISO si la moneda no está en la tabla.
    static func symbol(for currency: String) -> String {
        symbols[currency] ?? currency
    }

    /// Nombre para mostrar: "Sol peruano" / "Peruvian sol".
    static func name(for currency: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forCurrencyCode: currency) ?? currency
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// 500000 → "$5,000.00" (USD, en_US) · "$5.000" (CLP, es_CL) · "S/ 5,000.00" (PEN, es_PE).
    static func string(fromCents cents: Int, currency: String, locale: Locale = .current) -> String {
        let value = Decimal(cents) / Decimal(centsPerUnit)
        let digits = fractionDigits(for: currency)
        let number = abs(value).formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(digits))
                .rounded(rule: .toNearestOrAwayFromZero)
                .grouping(.automatic))
        let symbol = symbol(for: currency)
        // Los símbolos de varias letras ("S/", "R$") llevan un espacio: "S/ 100", "$100".
        let separator = symbol.count > 1 ? " " : ""
        return (cents < 0 ? "-" : "") + symbol + separator + number
    }

    /// Limpia lo que se escribe en un campo de monto: solo dígitos, un separador decimal
    /// y como máximo los decimales permitidos. "45.678" → "45.67"; "1.2.3" → "1.23".
    static func sanitizeInput(_ input: String, currency: String, locale: Locale = .current) -> String {
        let separator = Character(decimalSeparator(locale: locale))
        let decimals = inputDecimals(for: currency)
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

    /// Lo que escribe el usuario → centésimos. "4500" → 450000, "12.5" → 1250 (en_US).
    /// Devuelve nil si no hay un número válido o tiene más decimales de los permitidos.
    static func cents(fromInput input: String, currency: String, locale: Locale = .current) -> Int? {
        let separator = Character(decimalSeparator(locale: locale))
        let decimals = inputDecimals(for: currency)
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

    /// Centésimos → texto editable para un campo de monto: 125000 → "1250", 1250 → "12.50" (en_US).
    /// En monedas sin decimales (CLP) se muestra la parte entera.
    static func inputString(fromCents cents: Int, currency: String, locale: Locale = .current) -> String {
        let units = cents / centsPerUnit
        let remainder = abs(cents % centsPerUnit)
        guard inputDecimals(for: currency) > 0, remainder != 0 else { return "\(units)" }
        return "\(units)\(decimalSeparator(locale: locale))\(String(format: "%02d", remainder))"
    }

    /// Redondea a la unidad mínima que se puede escribir (CLP: pesos enteros; USD: centavos).
    static func roundedToInputable(_ cents: Int, currency: String) -> Int {
        guard inputDecimals(for: currency) == 0 else { return cents }
        return ((cents + centsPerUnit / 2) / centsPerUnit) * centsPerUnit
    }
}
