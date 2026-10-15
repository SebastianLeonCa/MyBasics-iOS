import Foundation

/// Exporta gastos a CSV (RFC 4180). Función pura: fácil de testear.
nonisolated enum CSVExporter {
    /// Montos con punto decimal y sin separador de miles, para que cualquier planilla los lea como número.
    static func csv(for expenses: [Expense], currency: String, calendar: Calendar = .app) -> String {
        let header = [
            String(localized: "Fecha"),
            String(localized: "Descripción"),
            String(localized: "Categoría"),
            String(localized: "Tipo"),
            String(localized: "Monto"),
            String(localized: "Costo neto"),
            String(localized: "Moneda"),
            String(localized: "Compartido con"),
            String(localized: "Monto compartido"),
            String(localized: "Dirección"),
            String(localized: "Pagado"),
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let rows = expenses.sorted { $0.spentAt < $1.spentAt }.map { expense -> [String] in
            let debt = expense.debts.first
            return [
                dateFormatter.string(from: expense.spentAt),
                expense.note ?? "",
                expense.category?.displayName ?? "",
                expense.kind.displayName,
                decimalString(expense.amountCents),
                decimalString(expense.netAmountCents),
                currency,
                debt?.counterpartyName ?? "",
                debt.map { decimalString($0.amountCents) } ?? "",
                debt?.direction.displayName ?? "",
                debt.map { $0.isSettled ? String(localized: "Sí") : String(localized: "No") } ?? "",
            ]
        }

        return ([header] + rows)
            .map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    /// 450050 → "4500.50"; -99 → "-0.99".
    static func decimalString(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = abs(cents)
        return String(format: "%@%d.%02d", sign, value / 100, value % 100)
    }

    /// Comillas si el campo tiene coma, comillas o saltos de línea; las comillas internas se duplican.
    /// Además, evita la "inyección de fórmulas" en Excel/Sheets anteponiendo ' a = + - @.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@".contains(first), Double(value) == nil {
            value = "'" + value
        }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// "MyBasics-2026-10.csv"
    static func fileName(for month: Date, calendar: Calendar = .app) -> String {
        let comps = calendar.dateComponents([.year, .month], from: month)
        return String(format: "MyBasics-%04d-%02d.csv", comps.year ?? 0, comps.month ?? 0)
    }

    /// Escribe el CSV (UTF-8 con BOM para que Excel respete los acentos) en una carpeta temporal.
    static func writeFile(for expenses: [Expense], month: Date, currency: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName(for: month))
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(csv(for: expenses, currency: currency).utf8))
        try data.write(to: url, options: .atomic)
        return url
    }
}
