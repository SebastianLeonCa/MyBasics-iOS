import Foundation

/// Encoder/decoder compartidos con Supabase: fechas ISO8601 con fracciones de segundo.
nonisolated enum JSONCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = parseISO8601(string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Fecha ISO8601 inválida: \(string)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// "2026-10-14T15:32:00.123Z" (UTC, con milisegundos).
    static func iso8601String(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// Acepta "2026-10-14T15:32:00Z", "2026-10-14T15:32:00.123Z" y "2026-10-14T15:32:00.123456+00:00".
    static func parseISO8601(_ string: String) -> Date? {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let d = try? withFraction.parse(string) { return d }
        if let d = try? Date.ISO8601FormatStyle().parse(string) { return d }
        // Postgres puede devolver microsegundos (6 dígitos): recortamos a milisegundos.
        if let dot = string.firstIndex(of: ".") {
            let fractionEnd = string[dot...].dropFirst().firstIndex { !$0.isNumber } ?? string.endIndex
            let digits = string[string.index(after: dot)..<fractionEnd]
            if digits.count > 3 {
                let trimmed = string[..<string.index(after: dot)] + digits.prefix(3) + string[fractionEnd...]
                return try? withFraction.parse(String(trimmed))
            }
        }
        return nil
    }
}
