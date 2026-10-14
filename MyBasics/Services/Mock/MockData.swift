import Foundation

/// Datos de ejemplo: ~40 gastos realistas en los últimos 3 meses (relativos a `now`),
/// algunos compartidos y varias suscripciones (una ya cancelada).
nonisolated enum MockData {
    private struct Seed {
        let monthOffset: Int   // 0 = mes actual, -1 = anterior, ...
        let day: Int
        let hour: Int
        let note: String?
        let category: String
        let cents: Int
        var kind: ExpenseKind = .variable
        var shared: (name: String, cents: Int, direction: DebtDirection, settled: Bool)? = nil
    }

    private static let seeds: [Seed] = {
        let subs = Category.subscriptionsName
        var list: [Seed] = []
        // Fijos y suscripciones, todos los meses.
        for m in [0, -1, -2] {
            list += [
                Seed(monthOffset: m, day: 1, hour: 9, note: "Arriendo", category: "Hogar", cents: 120_000, kind: .fixed),
                Seed(monthOffset: m, day: 3, hour: 8, note: "Gimnasio", category: "Salud", cents: 3_999, kind: .fixed),
                Seed(monthOffset: m, day: 5, hour: 10, note: "Netflix", category: subs, cents: 1_549, kind: .fixed),
                Seed(monthOffset: m, day: 7, hour: 10, note: "Spotify", category: subs, cents: 1_199, kind: .fixed),
                Seed(monthOffset: m, day: 10, hour: 11, note: "Plan celular", category: "Otros", cents: 2_500, kind: .fixed),
                Seed(monthOffset: m, day: 12, hour: 6, note: "iCloud+", category: subs, cents: 299, kind: .fixed),
            ]
        }
        // Suscripción cancelada: su último cobro fue hace dos meses.
        list.append(Seed(monthOffset: -2, day: 8, hour: 9, note: "Disney+", category: subs, cents: 1_399, kind: .fixed))

        list += [
            // Mes actual
            Seed(monthOffset: 0, day: 1, hour: 13, note: "Almuerzo", category: "Comida", cents: 1_250),
            Seed(monthOffset: 0, day: 2, hour: 19, note: "Walmart", category: "Supermercado", cents: 8_640),
            Seed(monthOffset: 0, day: 4, hour: 8, note: "Metro", category: "Transporte", cents: 2_000),
            Seed(monthOffset: 0, day: 6, hour: 21, note: "Cena con amigos", category: "Comida", cents: 6_400,
                 shared: ("Juan", 3_200, .theyOweMe, false)),
            Seed(monthOffset: 0, day: 8, hour: 17, note: "Farmacia", category: "Salud", cents: 1_849),
            Seed(monthOffset: 0, day: 9, hour: 20, note: "Cine", category: "Ocio", cents: 2_400,
                 shared: ("Camila", 1_200, .theyOweMe, false)),
            Seed(monthOffset: 0, day: 11, hour: 23, note: "Uber", category: "Transporte", cents: 1_375),
            Seed(monthOffset: 0, day: 13, hour: 10, note: "Starbucks", category: "Comida", cents: 585),
            Seed(monthOffset: 0, day: 14, hour: 15, note: "Red Bull", category: "Comida", cents: 325),
            // Mes anterior
            Seed(monthOffset: -1, day: 2, hour: 18, note: "Walmart", category: "Supermercado", cents: 9_312),
            Seed(monthOffset: -1, day: 4, hour: 13, note: "Sushi", category: "Comida", cents: 4_280,
                 shared: ("Pedro", 2_140, .theyOweMe, true)),
            Seed(monthOffset: -1, day: 7, hour: 9, note: "Gasolina", category: "Transporte", cents: 5_200),
            Seed(monthOffset: -1, day: 11, hour: 16, note: "Ferretería", category: "Hogar", cents: 2_735),
            Seed(monthOffset: -1, day: 15, hour: 22, note: "Concierto", category: "Ocio", cents: 8_500,
                 shared: ("Camila", 4_250, .iOweThem, false)),
            Seed(monthOffset: -1, day: 18, hour: 11, note: "Dentista", category: "Salud", cents: 12_000),
            Seed(monthOffset: -1, day: 24, hour: 19, note: "Walmart", category: "Supermercado", cents: 6_430),
            Seed(monthOffset: -1, day: 29, hour: 20, note: "Regalo cumpleaños", category: "Otros", cents: 4_000,
                 shared: ("Sofía", 2_000, .iOweThem, false)),
            // Hace dos meses
            Seed(monthOffset: -2, day: 3, hour: 19, note: "Walmart", category: "Supermercado", cents: 8_795),
            Seed(monthOffset: -2, day: 9, hour: 7, note: "Uber al aeropuerto", category: "Transporte", cents: 3_850,
                 shared: ("Juan", 1_925, .iOweThem, true)),
            Seed(monthOffset: -2, day: 12, hour: 17, note: "Lámpara", category: "Hogar", cents: 3_999),
            Seed(monthOffset: -2, day: 16, hour: 21, note: "Bar", category: "Ocio", cents: 4_650),
            Seed(monthOffset: -2, day: 23, hour: 13, note: nil, category: "Comida", cents: 1_100),
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
            comps.minute = (seed.cents / 7) % 60
            guard var date = calendar.date(from: comps) else { return nil }
            if date > now { date = now.addingTimeInterval(-600) }

            let debts = seed.shared.map { d in
                [Debt(counterpartyName: d.name, amountCents: d.cents, direction: d.direction,
                      isSettled: d.settled, settledAt: d.settled ? date.addingTimeInterval(86_400 * 3) : nil)]
            } ?? []

            return Expense(
                categoryId: category.id,
                amountCents: seed.cents,
                currency: "USD",
                kind: seed.kind,
                note: seed.note,
                spentAt: date,
                category: category,
                debts: debts
            )
        }
    }
}
