import SwiftUI

/// Suscripciones deducidas de los gastos de la categoría Suscripciones.
/// Activa = tuvo un cobro en los últimos 35 días.
struct SubscriptionsView: View {
    @State private var viewModel: SubscriptionsViewModel

    init(repository: any ExpenseRepository) {
        _viewModel = State(initialValue: SubscriptionsViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gasto mensual en suscripciones")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.string(
                            fromCents: viewModel.monthlyTotalCents,
                            currency: viewModel.currency ?? CurrencyFormatter.defaultCurrency))
                            .font(.largeTitle.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("\(viewModel.active.count) activas")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                if viewModel.hasLoaded && viewModel.summaries.isEmpty {
                    ContentUnavailableView(
                        "Sin suscripciones",
                        systemImage: "repeat.circle",
                        description: Text("Registra un gasto en la categoría Suscripciones (por ejemplo, Netflix) y aparecerá aquí.")
                    )
                } else {
                    if !viewModel.active.isEmpty {
                        Section("Activas") {
                            ForEach(viewModel.active) { row($0) }
                        }
                    }
                    if !viewModel.inactive.isEmpty {
                        Section {
                            ForEach(viewModel.inactive) { row($0) }
                        } header: {
                            Text("Inactivas")
                        } footer: {
                            Text("Sin cobros en los últimos \(SubscriptionAnalytics.activeWindowDays) días.")
                        }
                    }
                }
            }
            .navigationTitle("Suscripciones")
            .task { await viewModel.load() }
            .alert(
                "Algo salió mal",
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func row(_ item: SubscriptionSummary) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(icon: item.icon, colorHex: item.colorHex, size: 32)
                .opacity(item.isActive ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name)
                    .font(.body)
                Group {
                    if item.isActive {
                        Text("Próximo cobro ≈ \(item.nextChargeAt.formatted(.dateTime.day().month(.abbreviated)))")
                    } else {
                        Text("Último cobro: \(item.lastChargeAt.formatted(.dateTime.day().month(.abbreviated)))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(fromCents: item.lastAmountCents, currency: item.currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.isActive ? .primary : .secondary)
                if item.isActive {
                    Text("al mes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
