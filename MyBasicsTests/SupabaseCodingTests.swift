import XCTest
@testable import MyBasics

/// Lo que viaja hacia y desde Supabase, sin red.
final class SupabaseCodingTests: XCTestCase {
    func testDecodesNestedApiResponse() throws {
        // Respuesta de `select=*,category:categories(...),debts(*)` (con microsegundos, como Postgres).
        let json = #"""
        [{
          "id": "a3f1c2d4-8b7e-4c1a-9f10-2d5e6a7b8c90",
          "category_id": "5b2e0c11-0000-4000-8000-000000000001",
          "amount_cents": 250000, "currency": "USD", "kind": "variable",
          "note": "Red Bull", "spent_at": "2026-10-14T15:32:00.123456+00:00",
          "category": {"id": "5b2e0c11-0000-4000-8000-000000000001", "name": "Comida",
                       "color_hex": "#FF6B35", "icon": "fork.knife", "is_default": true},
          "debts": [{"id": "7c000000-0000-4000-8000-000000000001", "counterparty_name": "Juan",
                     "amount_cents": 125000, "direction": "they_owe_me", "is_settled": false, "settled_at": null}]
        }]
        """#
        let expenses = try JSONCoding.makeDecoder().decode([Expense].self, from: Data(json.utf8))
        let e = try XCTUnwrap(expenses.first)
        XCTAssertEqual(e.amountCents, 250_000)
        XCTAssertEqual(e.category?.name, "Comida")
        XCTAssertTrue(e.category?.isDefault == true)
        XCTAssertEqual(e.debts.first?.direction, .theyOweMe)
        XCTAssertTrue(e.hasPendingDebt)
        XCTAssertEqual(e.spentAt.timeIntervalSince1970, 1_791_991_920.123, accuracy: 0.001)
    }

    func testSaveExpenseParamsMatchSqlFunction() throws {
        var expense = Expense(
            categoryId: UUID(), amountCents: 6_400, currency: "USD", kind: .fixed, note: "Cena",
            spentAt: Date(timeIntervalSince1970: 1_791_991_920.5))
        expense.debts = [Debt(counterpartyName: "Juan", amountCents: 3_200, direction: .iOweThem)]

        let data = try JSONCoding.makeEncoder().encode(SaveExpenseParams(expense))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let p = try XCTUnwrap(object["p_expense"] as? [String: Any])
        let debts = try XCTUnwrap(object["p_debts"] as? [[String: Any]])

        XCTAssertEqual(p["id"] as? String, expense.id.uuidString)
        XCTAssertEqual(p["amount_cents"] as? Int, 6_400)
        XCTAssertEqual(p["kind"] as? String, "fixed")
        XCTAssertEqual(p["spent_at"] as? String, "2026-10-14T15:32:00.500Z")
        XCTAssertNil(p["category"], "la categoría embebida no se envía")
        XCTAssertEqual(debts.first?["direction"] as? String, "i_owe_them")
        XCTAssertEqual(debts.first?["is_settled"] as? Bool, false)
    }

    func testNewCategoriesAreNeverSentAsDefault() throws {
        let category = MyBasics.Category(name: "Mascotas", colorHex: "#8AC926", icon: "pawprint", isDefault: true)
        let data = try JSONCoding.makeEncoder().encode(CategoryInsert(category))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["is_default"] as? Bool, false)
        XCTAssertNil(object["user_id"], "user_id lo pone la base de datos con auth.uid()")
    }

    @MainActor
    func testOfflineErrorIsFriendly() {
        let message = UserFacingError.describe(URLError(.notConnectedToInternet))
        XCTAssertFalse(message.isEmpty)
        XCTAssertNotEqual(message, URLError(.notConnectedToInternet).localizedDescription)
    }
}
