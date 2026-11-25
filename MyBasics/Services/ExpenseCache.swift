import Foundation

/// Caché local del mes en curso para que la app abra al instante (luego se refresca desde la red).
/// Se guarda por usuario, así una cuenta nunca ve los datos de otra.
protocol ExpenseCache: AnyObject {
    func expenses(for month: Date, userId: UUID) -> [Expense]?
    func store(_ expenses: [Expense], for month: Date, userId: UUID)
    func removeAll()
}

/// Archivos JSON en Library/Caches (iOS puede borrarlos si necesita espacio; no es un problema).
final class FileExpenseCache: ExpenseCache {
    private let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        self.directory = directory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ExpenseCache", isDirectory: true)
    }

    func expenses(for month: Date, userId: UUID) -> [Expense]? {
        guard let data = try? Data(contentsOf: fileURL(month: month, userId: userId)) else { return nil }
        return try? JSONCoding.makeDecoder().decode([Expense].self, from: data)
    }

    func store(_ expenses: [Expense], for month: Date, userId: UUID) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Solo se guarda un mes por usuario: el más reciente.
            let prefix = userId.uuidString + "_"
            for file in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] where file.hasPrefix(prefix) {
                try? fileManager.removeItem(at: directory.appendingPathComponent(file))
            }
            let data = try JSONCoding.makeEncoder().encode(expenses)
            try data.write(to: fileURL(month: month, userId: userId), options: [.atomic, .completeFileProtection])
        } catch {
            // La caché es una optimización: si falla, la app sigue funcionando desde la red.
        }
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
    }

    private func fileURL(month: Date, userId: UUID) -> URL {
        let comps = Calendar.app.dateComponents([.year, .month], from: month)
        let name = String(format: "%@_%04d-%02d.json", userId.uuidString, comps.year ?? 0, comps.month ?? 0)
        return directory.appendingPathComponent(name)
    }
}

/// Para tests y modo de ejemplo.
final class InMemoryExpenseCache: ExpenseCache {
    private var storage: [String: [Expense]] = [:]

    private func key(_ month: Date, _ userId: UUID) -> String {
        "\(userId.uuidString)_\(month.startOfMonth().timeIntervalSince1970)"
    }

    func expenses(for month: Date, userId: UUID) -> [Expense]? { storage[key(month, userId)] }
    func store(_ expenses: [Expense], for month: Date, userId: UUID) { storage[key(month, userId)] = expenses }
    func removeAll() { storage.removeAll() }
}
