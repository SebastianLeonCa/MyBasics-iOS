import SwiftUI

struct DebtsView: View {
    @State private var viewModel: DebtsViewModel
    let currency: String

    init(repository: any ExpenseRepository, currency: String) {
        _viewModel = State(initialValue: DebtsViewModel(repository: repository))
        self.currency = currency
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    totalTile(title: "Me deben", cents: viewModel.theyOweMeCents, color: .green,
                              icon: "arrow.down.left")
                    totalTile(title: "Yo debo", cents: viewModel.iOweThemCents, color: .orange,
                              icon: "arrow.up.right")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if viewModel.items.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "Sin deudas pendientes",
                    systemImage: "checkmark.circle",
                    description: Text("Cuando registres un gasto con deuda aparecerá aquí.")
                )
            } else {
                Section("Pendientes") {
                    ForEach(viewModel.items) { item in
                        row(item)
                    }
                }
            }
        }
        .navigationTitle("Deudas")
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

    private func totalTile(title: String, cents: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            Text(CurrencyFormatter.string(fromCents: cents, currency: currency))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: PendingDebtItem) -> some View {
        let theyOweMe = item.debt.direction == .theyOweMe
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.debt.counterpartyName)
                    .font(.body.weight(.medium))
                Text("\(item.expense.displayTitle) · \(item.expense.spentAt.formatted(.dateTime.day().month(.abbreviated).locale(CurrencyFormatter.locale)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(fromCents: item.debt.amountCents, currency: item.expense.currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(item.debt.direction.displayName)
                    .font(.caption)
                    .foregroundStyle(theyOweMe ? .green : .orange)
            }
            Button {
                Task { await viewModel.settle(item) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Marcar como saldada")
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Marcar como saldada") {
            Task { await viewModel.settle(item) }
        }
    }
}
