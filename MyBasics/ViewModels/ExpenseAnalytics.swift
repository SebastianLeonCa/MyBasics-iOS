import Foundation

/// Filtro del selector segmentado de Home.
nonisolated enum KindFilter: String, CaseIterable, Identifiable, Sendable {
    case all, fixed, variable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "Todos"
        case .fixed: "Fijos"
        case .variable: "Variables"
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
    var totalCents: Int { expenses.reduce(0) { $0 + $1.amountCents } }
}

/// Funciones puras (sin estado) que usa HomeViewModel. Cubiertas por tests unitarios.
nonisolated enum ExpenseAnalytics {
    static func filter(_ expenses: [Expense], by filter: KindFilter) -> [Expense] {
        expenses.filter(filter.matches)
    }

    static func total(_ expenses: [Expense]) -> Int {
        expenses.reduce(0) { $0 + $1.amountCents }
    }

    /// Totales por categoría, de mayor a menor (empate: por nombre).
    static func categoryTotals(_ expenses: [Expense]) -> [CategoryTotal] {
        let grandTotal = total(expenses)
        guard grandTotal > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses, by: \.categoryId)
        return grouped.map { categoryId, items in
            let amount = total(items)
            let category = items.first?.category
            return CategoryTotal(
                categoryId: categoryId,
                name: category?.name ?? "Sin categoría",
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

    /// "Hoy", "Ayer", "12 oct" (o "12 oct 2025" si es de otro año).
    static func dayTitle(for day: Date, now: Date = .now, calendar: Calendar = .app) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Hoy" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) { return "Ayer" }

        let sameYear = calendar.isDate(day, equalTo: now, toGranularity: .year)
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = calendar.locale
        f.timeZone = calendar.timeZone
        f.dateFormat = sameYear ? "d MMM" : "d MMM yyyy"
        return f.string(from: day).replacingOccurrences(of: ".", with: "")
    }
}
