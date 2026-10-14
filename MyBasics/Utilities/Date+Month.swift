import Foundation

nonisolated extension Calendar {
    /// Calendario usado en toda la app (semana desde lunes, español de Chile).
    static var app: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "es_CL")
        cal.timeZone = .current
        return cal
    }
}

nonisolated extension Date {
    /// Primer instante del mes de esta fecha.
    func startOfMonth(calendar: Calendar = .app) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }

    /// Rango [inicio del mes, inicio del mes siguiente). Ideal para consultas `gte`/`lt`.
    func monthInterval(calendar: Calendar = .app) -> DateInterval {
        let start = startOfMonth(calendar: calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// Suma (o resta) meses y devuelve el inicio de ese mes.
    func addingMonths(_ months: Int, calendar: Calendar = .app) -> Date {
        let start = startOfMonth(calendar: calendar)
        return calendar.date(byAdding: .month, value: months, to: start) ?? start
    }

    /// "Octubre 2026"
    func monthTitle(calendar: Calendar = .app) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = calendar.locale
        f.timeZone = calendar.timeZone
        f.dateFormat = "LLLL yyyy"
        return f.string(from: self).capitalized(with: calendar.locale)
    }

    func isSameMonth(as other: Date, calendar: Calendar = .app) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .month)
    }
}
