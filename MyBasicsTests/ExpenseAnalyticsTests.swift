import XCTest
@testable import MyBasics

final class ExpenseAnalyticsTests: XCTestCase {
    private typealias F = Fixtures

    private lazy var sample: [Expense] = [
        F.expense(F.home, units: 450_000, kind: .fixed, at: F.date(2026, 10, 1, 9)),
        F.expense(F.food, units: 8_000, at: F.date(2026, 10, 12, 13)),
        F.expense(F.food, units: 2_000, at: F.date(2026, 10, 12, 18)),
        F.expense(F.transport, units: 10_000, at: F.date(2026, 10, 14, 8)),
    ]

    // MARK: Filtro y total

    func testFilterByKind() {
        XCTAssertEqual(ExpenseAnalytics.filter(sample, by: .all).count, 4)
        XCTAssertEqual(ExpenseAnalytics.filter(sample, by: .fixed).map(\.categoryId), [F.home.id])
        XCTAssertEqual(ExpenseAnalytics.filter(sample, by: .variable).count, 3)
    }

    func testTotalIsSumOfCents() {
        XCTAssertEqual(ExpenseAnalytics.total(sample), 47_000_000)
        XCTAssertEqual(ExpenseAnalytics.total([]), 0)
    }

    // MARK: Totales por categoría

    func testCategoryTotalsAreGroupedAndSortedDescending() {
        let totals = ExpenseAnalytics.categoryTotals(ExpenseAnalytics.filter(sample, by: .variable))

        XCTAssertEqual(totals.map(\.categoryId), [F.food.id, F.transport.id])   // empate de monto → por nombre
        XCTAssertEqual(totals.map(\.amountCents), [1_000_000, 1_000_000])
        XCTAssertEqual(totals[0].share, 0.5, accuracy: 0.0001)
    }

    func testCategoryTotalsSharesAddUpToOne() {
        let totals = ExpenseAnalytics.categoryTotals(sample)

        XCTAssertEqual(totals.first?.categoryId, F.home.id)
        XCTAssertEqual(totals.map(\.amountCents).reduce(0, +), ExpenseAnalytics.total(sample))
        XCTAssertEqual(totals.map(\.share).reduce(0, +), 1, accuracy: 0.0001)
    }

    func testCategoryTotalsEmptyWhenNoExpenses() {
        XCTAssertTrue(ExpenseAnalytics.categoryTotals([]).isEmpty)
    }

    // MARK: Agrupación por día

    func testGroupByDayOrdersDaysAndItemsNewestFirst() {
        let sections = ExpenseAnalytics.groupByDay(sample, calendar: F.calendar)

        XCTAssertEqual(sections.map(\.day), [
            F.calendar.startOfDay(for: F.date(2026, 10, 14)),
            F.calendar.startOfDay(for: F.date(2026, 10, 12)),
            F.calendar.startOfDay(for: F.date(2026, 10, 1)),
        ])
        XCTAssertEqual(sections[1].expenses.map(\.amountCents), [200_000, 800_000])   // 18:00 antes que 13:00
        XCTAssertEqual(sections[1].totalCents, 1_000_000)
    }

    func testDayLabel() {
        let now = F.date(2026, 10, 14, 15)
        XCTAssertEqual(ExpenseAnalytics.dayLabel(for: F.date(2026, 10, 14, 0), now: now, calendar: F.calendar), .today)
        XCTAssertEqual(ExpenseAnalytics.dayLabel(for: F.date(2026, 10, 13, 23), now: now, calendar: F.calendar), .yesterday)
        XCTAssertEqual(ExpenseAnalytics.dayLabel(for: F.date(2026, 10, 12, 0), now: now, calendar: F.calendar), .thisYear)
        XCTAssertEqual(ExpenseAnalytics.dayLabel(for: F.date(2025, 12, 3, 0), now: now, calendar: F.calendar), .otherYear)
    }

    func testDayTitleUsesCalendarLocale() {
        let now = F.date(2026, 10, 14, 15)
        var spanish = F.calendar
        spanish.locale = Locale(identifier: "es_ES")
        var english = F.calendar
        english.locale = Locale(identifier: "en_US")
        XCTAssertTrue(ExpenseAnalytics.dayTitle(for: F.date(2026, 10, 12), now: now, calendar: spanish).hasPrefix("12 oct"))
        XCTAssertEqual(ExpenseAnalytics.dayTitle(for: F.date(2026, 10, 12), now: now, calendar: english), "Oct 12")
    }
}
