import Foundation

/// Filtro del selector segmentado de Home.
nonisolated enum KindFilter: String, CaseIterable, Identifiable, Sendable {
    case all, fixed, variable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: String(localized: "Todos")
        case .fixed: String(localized: "Fijos")
        case .variable: String(localized: "Variables")
        }
    }

    func matches(_ expense: Expense) -> Bool {
        switch self {
        case .all: true
        case .fixed: expense.kind == .fixed
        case .variable: expense.kind == .variable
        }
    }
}

/// Total de una categoría en el período, para el gráfico y la leyenda.
nonisolated struct CategoryTotal: Identifiable, Hashable, Sendable {
    var id: UUID { categoryId }
    let categoryId: UUID
    let name: String
    let colorHex: String
    let icon: String
    let amountCents: Int
    /// Fracción del total (0...1). Es un porcentaje para mostrar, no dinero.
    let share: Double
}

/// Gastos de un mismo día, para la lista agrupada.
nonisolated struct DaySection: Identifiable, Hashable, Sendable {
    var id: Date { day }
    /// Inicio del día.
    let day: Date
    let expenses: [Expense]
    var totalCents: Int { expenses.reduce(0) { $0 + $1.netAmountCents } }
}

/// Funciones puras (sin estado) que usa HomeViewModel. Cubiertas por tests unitarios.
nonisolated enum ExpenseAnalytics {
    static func filter(_ expenses: [Expense], by filter: KindFilter) -> [Expense] {
        expenses.filter(filter.matches)
    }

    /// Suma de lo que de verdad costó cada gasto (neto de lo que ya te devolvieron).
    static func total(_ expenses: [Expense]) -> Int {
        expenses.reduce(0) { $0 + $1.netAmountCents }
    }

    /// Totales por categoría, de mayor a menor (empate: por nombre). Las categorías que quedan
    /// en $0 (p. ej. todo te lo devolvieron) no aparecen.
    static func categoryTotals(_ expenses: [Expense]) -> [CategoryTotal] {
        let grandTotal = total(expenses)
        guard grandTotal > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses, by: \.categoryId)
        return grouped.compactMap { categoryId, items -> CategoryTotal? in
            let amount = total(items)
            guard amount > 0 else { return nil }
            let category = items.first?.category
            return CategoryTotal(
                categoryId: categoryId,
                name: category?.displayName ?? String(localized: "Sin categoría"),
                colorHex: category?.colorHex ?? "#8E8E93",
                icon: category?.icon ?? "tag",
                amountCents: amount,
                share: Double(amount) / Double(grandTotal)
            )
        }
        .sorted { lhs, rhs in
            lhs.amountCents != rhs.amountCents ? lhs.amountCents > rhs.amountCents : lhs.name < rhs.name
        }
    }

    /// Agrupa por día: días más recientes primero y, dentro del día, los más recientes primero.
    static func groupByDay(_ expenses: [Expense], calendar: Calendar = .app) -> [DaySection] {
        Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.spentAt) }
            .map { day, items in
                DaySection(day: day, expenses: items.sorted { $0.spentAt > $1.spentAt })
            }
            .sorted { $0.day > $1.day }
    }

    /// Qué tan reciente es un día (sin texto: así se puede testear sin depender del idioma).
    static func dayLabel(for day: Date, now: Date = .now, calendar: Calendar = .app) -> DayLabel {
        if calendar.isDate(day, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) { return .yesterday }
        return calendar.isDate(day, equalTo: now, toGranularity: .year) ? .thisYear : .otherYear
    }

    /// "Hoy", "Ayer", "12 oct" (o "12 oct 2025" si es de otro año), en el idioma del dispositivo.
    static func dayTitle(for day: Date, now: Date = .now, calendar: Calendar = .app) -> String {
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).locale(calendar.locale ?? .current)
        switch dayLabel(for: day, now: now, calendar: calendar) {
        case .today: return String(localized: "Hoy")
        case .yesterday: return String(localized: "Ayer")
        case .thisYear: return day.formatted(style.day().month(.abbreviated))
        case .otherYear: return day.formatted(style.day().month(.abbreviated).year())
        }
    }
}

nonisolated enum DayLabel: Equatable, Sendable {
    case today, yesterday, thisYear, otherYear
}
