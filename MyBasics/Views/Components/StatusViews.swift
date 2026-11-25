import SwiftUI

extension View {
    /// Alerta de error con botón "Reintentar" cuando la acción se puede repetir.
    func errorAlert(_ error: Binding<UserFacingError?>) -> some View {
        alert(
            error.wrappedValue?.title ?? "",
            isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }),
            presenting: error.wrappedValue
        ) { value in
            if let retry = value.retry {
                Button("Reintentar") { Task { await retry() } }
                Button("Cancelar", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { value in
            Text(value.message)
        }
    }
}

/// Error de carga a pantalla completa (dentro de una List) con "Reintentar".
struct LoadErrorView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
        }
    }
}

/// Filas "fantasma" mientras carga (efecto skeleton con `.redacted`).
struct SkeletonRows: View {
    var count = 5

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            HStack(spacing: 12) {
                Circle().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: index.isMultiple(of: 2) ? "Supermercado" : "Almuerzo")
                    Text(verbatim: "Variable").font(.caption2)
                }
                Spacer()
                Text(verbatim: "$00.00").fontWeight(.semibold)
            }
            .foregroundStyle(Theme.surfaceRaised)
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
        }
    }
}
