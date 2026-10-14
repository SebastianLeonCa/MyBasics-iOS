import XCTest
@testable import MyBasics

final class SubscriptionAnalyticsTests: XCTestCase {
    private typealias F = Fixtures
    private let subs = MyBasics.Category(name: MyBasics.Category.subscriptionsName, colorHex: "#5E60CE",
                                         icon: "repeat", isDefault: true)

    func testGroupsByNameAndDetectsActive() {
        let now = F.date(2026, 10, 14, 15)
        let expenses = [
            F.expense(subs, units: 15, kind: .fixed, at: F.date(2026, 10, 5), note: "Netflix"),
            F.expense(subs, units: 15, kind: .fixed, at: F.date(2026, 9, 5), note: "netflix "),
            F.expense(subs, units: 14, kind: .fixed, at: F.date(2026, 8, 8), note: "Disney+"),
            F.expense(subs, units: 3, kind: .fixed, at: F.date(2026, 9, 12), note: "iCloud+"),
            F.expense(Fixtures.food, units: 99, at: F.date(2026, 10, 1), note: "Netflix"),   // otra categoría
        ]

        let summaries = SubscriptionAnalytics.summaries(from: expenses, now: now, calendar: F.calendar)

        XCTAssertEqual(summaries.map(\.name), ["Netflix", "iCloud+", "Disney+"])
        XCTAssertEqual(summaries.map(\.isActive), [true, true, false])
        XCTAssertEqual(summaries[0].chargeCount, 2)
        XCTAssertEqual(summaries[0].nextChargeAt, F.date(2026, 11, 5))
        XCTAssertEqual(SubscriptionAnalytics.monthlyActiveTotal(summaries), 1_800)
    }

    func testMockDataHasActiveAndCancelledSubscriptions() {
        let now = F.date(2026, 10, 14, 15)
        let expenses = MockData.expenses(categories: MyBasics.Category.defaults, now: now)
        let summaries = SubscriptionAnalytics.summaries(from: expenses, now: now)
        XCTAssertEqual(Set(summaries.filter(\.isActive).map(\.name)), ["Netflix", "Spotify", "iCloud+"])
        XCTAssertEqual(summaries.filter { !$0.isActive }.map(\.name), ["Disney+"])
    }
}

final class SharedBalancesTests: XCTestCase {
    private typealias F = Fixtures

    func testNetBalancePerPerson() {
        var dinner = F.expense(F.food, units: 60, at: F.date(2026, 10, 6))
        dinner.debts = [Debt(counterpartyName: "Juan", amountCents: 3_000, direction: .theyOweMe)]
        var taxi = F.expense(F.transport, units: 20, at: F.date(2026, 10, 7))
        taxi.debts = [Debt(counterpartyName: "juan ", amountCents: 1_000, direction: .iOweThem)]
        var concert = F.expense(F.food, units: 80, at: F.date(2026, 10, 1))
        concert.debts = [Debt(counterpartyName: "Ana", amountCents: 4_000, direction: .iOweThem),
                         Debt(counterpartyName: "Pedro", amountCents: 500, direction: .theyOweMe, isSettled: true)]

        let shares = SharedBalances.pendingShares(from: [dinner, taxi, concert])
        XCTAssertEqual(shares.count, 3, "lo pagado no cuenta")

        let balances = SharedBalances.balances(from: shares)
        XCTAssertEqual(balances.map(\.name), ["Ana", "Juan"])
        XCTAssertEqual(balances.map(\.netCents), [-4_000, 2_000])
        XCTAssertEqual(SharedBalances.total(shares, direction: .theyOweMe), 3_000)
        XCTAssertEqual(SharedBalances.total(shares, direction: .iOweThem), 5_000)
    }

    @MainActor
    func testMarkPaidRemovesItAndUpdatesTotals() async throws {
        let now = F.date(2026, 10, 14, 15)
        let repo = MockExpenseRepository(expenses: MockData.expenses(categories: MyBasics.Category.defaults, now: now))
        let vm = SharedViewModel(repository: repo)
        await vm.load()
        let before = vm.shares.count
        let share = try XCTUnwrap(vm.shares.first { $0.debt.direction == .theyOweMe })
        let owedBefore = vm.owedToMeCents

        await vm.markPaid(share)

        XCTAssertEqual(vm.shares.count, before - 1)
        XCTAssertEqual(vm.owedToMeCents, owedBefore - share.debt.amountCents)
        await vm.load()
        XCTAssertFalse(vm.shares.contains { $0.id == share.id }, "persistido en el repositorio")
    }
}
