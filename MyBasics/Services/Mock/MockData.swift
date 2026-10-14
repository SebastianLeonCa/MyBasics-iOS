import Foundation

/// Datos de ejemplo: ~40 gastos realistas en los últimos 3 meses (relativos a `now`), algunos con deudas.
nonisolated enum MockData {
    private struct Seed {
        let monthOffset: Int   // 0 = mes actual, -1 = anterior, ...
        let day: Int
        let hour: Int
        let note: String?
        let category: String
        let pesos: Int         // en pesos; se convierte a centavos (×100)
        var kind: ExpenseKind = .variable
        var debt: (name: String, pesos: Int, direction: DebtDirection, settled: Bool)? = nil
    }

    private static let seeds: [Seed] = {
        var list: [Seed] = []
        // Gastos fijos, todos los meses.
        for m in [0, -1, -2] {
            list += [
                Seed(monthOffset: m, day: 1, hour: 9, note: "Arriendo", category: "Hogar", pesos: 450_000, kind: .fixed),
                Seed(monthOffset: m, day: 3, hour: 8, note: "Gimnasio", category: "Salud", pesos: 29_990, kind: .fixed),
                Seed(monthOffset: m, day: 5, hour: 10, note: "Netflix", category: "Ocio", pesos: 9_990, kind: .fixed),
                Seed(monthOffset: m, day: 10, hour: 11, note: "Plan celular", category: "Otros", pesos: 15_990, kind: .fixed),
            ]
        }
        // Variables.
        list += [
            // Mes actual
            Seed(monthOffset: 0, day: 1, hour: 13, note: "Almuerzo", category: "Comida", pesos: 8_500),
            Seed(monthOffset: 0, day: 2, hour: 19, note: "Jumbo", category: "Supermercado", pesos: 54_320),
            Seed(monthOffset: 0, day: 4, hour: 8, note: "Bip!", category: "Transporte", pesos: 10_000),
            Seed(monthOffset: 0, day: 6, hour: 21, note: "Cena con amigos", category: "Comida", pesos: 42_000,
                 debt: ("Juan", 21_000, .theyOweMe, false)),
            Seed(monthOffset: 0, day: 8, hour: 17, note: "Farmacia", category: "Salud", pesos: 12_490),
            Seed(monthOffset: 0, day: 9, hour: 20, note: "Cine", category: "Ocio", pesos: 14_000,
                 debt: ("Camila", 7_000, .theyOweMe, false)),
            Seed(monthOffset: 0, day: 11, hour: 23, note: "Uber", category: "Transporte", pesos: 6_800),
            Seed(monthOffset: 0, day: 12, hour: 12, note: "Lider", category: "Supermercado", pesos: 23_150),
            Seed(monthOffset: 0, day: 13, hour: 10, note: nil, category: "Comida", pesos: 3_200),
            Seed(monthOffset: 0, day: 14, hour: 15, note: "Red Bull", category: "Comida", pesos: 2_500),
            // Mes anterior
            Seed(monthOffset: -1, day: 2, hour: 18, note: "Jumbo", category: "Supermercado", pesos: 61_870),
            Seed(monthOffset: -1, day: 4, hour: 13, note: "Sushi", category: "Comida", pesos: 18_900,
                 debt: ("Pedro", 9_450, .theyOweMe, true)),
            Seed(monthOffset: -1, day: 7, hour: 9, note: "Bencina", category: "Transporte", pesos: 45_000),
            Seed(monthOffset: -1, day: 11, hour: 16, note: "Ferretería", category: "Hogar", pesos: 17_380),
            Seed(monthOffset: -1, day: 15, hour: 22, note: "Concierto", category: "Ocio", pesos: 38_000,
                 debt: ("Camila", 38_000, .iOweThem, false)),
            Seed(monthOffset: -1, day: 18, hour: 11, note: "Dentista", category: "Salud", pesos: 35_000),
            Seed(monthOffset: -1, day: 21, hour: 13, note: "Almuerzo", category: "Comida", pesos: 9_200),
            Seed(monthOffset: -1, day: 24, hour: 19, note: "Lider", category: "Supermercado", pesos: 28_640),
            Seed(monthOffset: -1, day: 27, hour: 8, note: "Bip!", category: "Transporte", pesos: 10_000),
            Seed(monthOffset: -1, day: 29, hour: 20, note: "Regalo cumpleaños", category: "Otros", pesos: 25_000,
                 debt: ("Sofía", 12_500, .iOweThem, false)),
            // Hace dos meses
            Seed(monthOffset: -2, day: 3, hour: 19, note: "Jumbo", category: "Supermercado", pesos: 58_210),
            Seed(monthOffset: -2, day: 6, hour: 14, note: "Completos", category: "Comida", pesos: 6_400),
            Seed(monthOffset: -2, day: 9, hour: 7, note: "Uber al aeropuerto", category: "Transporte", pesos: 22_500,
                 debt: ("Juan", 11_250, .iOweThem, true)),
            Seed(monthOffset: -2, day: 12, hour: 17, note: "Lámpara", category: "Hogar", pesos: 24_990),
            Seed(monthOffset: -2, day: 16, hour: 21, note: "Bar", category: "Ocio", pesos: 19_500),
            Seed(monthOffset: -2, day: 19, hour: 10, note: "Exámenes", category: "Salud", pesos: 21_300),
            Seed(monthOffset: -2, day: 23, hour: 13, note: nil, category: "Comida", pesos: 7_800),
            Seed(monthOffset: -2, day: 26, hour: 18, note: "Feria", category: "Supermercado", pesos: 15_600),
        ]
        return list
    }()

    static func expenses(categories: [Category], now: Date = .now, calendar: Calendar = .app) -> [Expense] {
        let byName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })

        return seeds.compactMap { seed -> Expense? in
            guard let category = byName[seed.category] else { return nil }

            let monthStart = now.addingMonths(seed.monthOffset, calendar: calendar)
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 28
            var day = min(seed.day, daysInMonth)
            if seed.monthOffset == 0 {
                day = min(day, calendar.component(.day, from: now))   // nada en el futuro
            }
            var comps = calendar.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            comps.hour = seed.hour
            comps.minute = (seed.pesos / 100) % 60
            guard var date = calendar.date(from: comps) else { return nil }
            if date > now { date = now.addingTimeInterval(-600) }

            let debts = seed.debt.map { d in
                [Debt(counterpartyName: d.name, amountCents: d.pesos * 100, direction: d.direction,
                      isSettled: d.settled, settledAt: d.settled ? date.addingTimeInterval(86_400 * 3) : nil)]
            } ?? []

            return Expense(
                categoryId: category.id,
                amountCents: seed.pesos * 100,
                currency: "CLP",
                kind: seed.kind,
                note: seed.note,
                spentAt: date,
                category: category,
                debts: debts
            )
        }
    }
}
