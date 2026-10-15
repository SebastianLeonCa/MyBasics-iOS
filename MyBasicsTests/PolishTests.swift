import XCTest
@testable import MyBasics

final class CSVExporterTests: XCTestCase {
    private typealias F = Fixtures

    func testCsvHasHeaderRowsSortedAndPlainDecimals() {
        var dinner = F.expense(F.food, units: 0, at: F.date(2026, 10, 6, 21, 30), note: "Cena")
        dinner.amountCents = 450_050
        dinner.debts = [Debt(counterpartyName: "Juan", amountCents: 2_525, direction: .theyOweMe)]
        let rent = F.expense(F.home, units: 1_200, kind: .fixed, at: F.date(2026, 10, 1, 9), note: "Arriendo")

        let lines = CSVExporter.csv(for: [dinner, rent], calendar: F.calendar)
            .components(separatedBy: "\r\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].split(separator: ",").count, 11)
        XCTAssertTrue(lines[1].hasPrefix("2026-10-01 09:00,Arriendo,"), "ordenado por fecha")
        XCTAssertTrue(lines[1].contains(",1200.00,1200.00,USD,"), lines[1])
        XCTAssertTrue(lines[2].contains(",4500.50,4500.50,USD,Juan,25.25,"), "pendiente: aún no resta · \(lines[2])")
    }

    func testEscapesCommasQuotesAndFormulas() {
        XCTAssertEqual(CSVExporter.escape("Pan, leche"), "\"Pan, leche\"")
        XCTAssertEqual(CSVExporter.escape("El \"mejor\""), "\"El \"\"mejor\"\"\"")
        XCTAssertEqual(CSVExporter.escape("=HYPERLINK(1)"), "'=HYPERLINK(1)")
        XCTAssertEqual(CSVExporter.escape("-0.99"), "-0.99", "los números negativos no se tocan")
        XCTAssertEqual(CSVExporter.decimalString(5), "0.05")
        XCTAssertEqual(CSVExporter.fileName(for: F.date(2026, 3, 1), calendar: F.calendar), "MyBasics-2026-03.csv")
    }

    func testWritesUtf8FileWithBom() throws {
        let url = try CSVExporter.writeFile(
            for: [F.expense(F.food, units: 3, at: F.date(2026, 10, 2), note: "Café")], month: F.date(2026, 10, 1))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("Café"))
    }
}

@MainActor
final class CacheTests: XCTestCase {
    private typealias F = Fixtures
    private let now = Fixtures.date(2026, 10, 14, 15)
    private let user = UUID()

    func testFileCacheRoundTripsAndIsPerUser() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = FileExpenseCache(directory: dir)
        var expense = F.expense(F.food, units: 12, at: F.date(2026, 10, 3), note: "Pizza")
        expense.debts = [Debt(counterpartyName: "Ana", amountCents: 600, direction: .iOweThem)]

        cache.store([expense], for: now.startOfMonth(), userId: user)
        let loaded = try XCTUnwrap(cache.expenses(for: now.startOfMonth(), userId: user))
        XCTAssertEqual(loaded.first?.id, expense.id)
        XCTAssertEqual(loaded.first?.category?.name, "Comida")
        XCTAssertEqual(loaded.first?.debts.first?.counterpartyName, "Ana")
        XCTAssertNil(cache.expenses(for: now.startOfMonth(), userId: UUID()), "otro usuario no ve esta caché")

        cache.store([], for: F.date(2026, 11, 1), userId: user)
        XCTAssertNil(cache.expenses(for: now.startOfMonth(), userId: user), "solo se guarda el mes más reciente")
    }

    func testHomeShowsCacheFirstThenRefreshes() async {
        let cached = F.expense(F.food, units: 1, at: F.date(2026, 10, 1))
        let fresh = F.expense(F.food, units: 2, at: F.date(2026, 10, 2))
        let cache = InMemoryExpenseCache()
        cache.store([cached], for: now.startOfMonth(), userId: user)
        let repo = FlakyExpenseRepository(expenses: [fresh])
        repo.failReads = true
        let now = self.now, user = self.user
        let vm = HomeViewModel(repository: repo, cache: cache, userId: { user }, now: { now })

        await vm.load()   // sin red: queda la caché y se avisa
        XCTAssertEqual(vm.expenses.map(\.id), [cached.id])
        XCTAssertTrue(vm.isShowingCachedData)
        XCTAssertNil(vm.loadError)
        XCTAssertNotNil(vm.alert?.retry)

        repo.failReads = false
        await vm.load()
        XCTAssertEqual(vm.expenses.map(\.id), [fresh.id])
        XCTAssertFalse(vm.isShowingCachedData)
        XCTAssertEqual(cache.expenses(for: now.startOfMonth(), userId: user)?.map(\.id), [fresh.id], "la caché se actualiza")
    }

    func testHapticCountersFireOnSaveDeleteAndError() async {
        let repo = FlakyExpenseRepository(expenses: [])
        let now = self.now
        let vm = HomeViewModel(repository: repo, now: { now })
        await vm.load()
        let expense = F.expense(F.food, units: 4, at: F.date(2026, 10, 4))
        await vm.save(expense, isNew: true)
        XCTAssertEqual(vm.savedFeedback, 1)
        await vm.delete(expense)
        XCTAssertEqual(vm.deletedFeedback, 1)
        repo.failWrites = true
        await vm.save(expense, isNew: true)
        XCTAssertEqual(vm.errorFeedback, 1)
    }

    func testCurrencyIsRemembered() throws {
        let suite = "test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(AppEnvironment.mock(defaults: defaults).currency, "USD")
        AppEnvironment.mock(defaults: defaults).currency = "EUR"
        XCTAssertEqual(AppEnvironment.mock(defaults: defaults).currency, "EUR")
    }
}
