import SwiftUI

/// "Compartidos": gastos que dividiste con alguien. Agrupado por persona con su saldo neto.
struct SharedView: View {
    @State private var viewModel: SharedViewModel

    init(repository: any ExpenseRepository) {
        _viewModel = State(initialValue: SharedViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        totalTile(title: "Te deben", cents: viewModel.owedToMeCents, color: .green,
                                  icon: "arrow.down.left")
                        totalTile(title: "Debes", cents: viewModel.iOweCents, color: .orange,
                                  icon: "arrow.up.right")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let loadError = viewModel.loadError {
                    LoadErrorView(message: loadError) { await viewModel.load() }
                } else if !viewModel.hasLoaded {
                    Section { SkeletonRows(count: 3) }
                } else if viewModel.shares.isEmpty {
                    ContentUnavailableView(
                        "Todo al día",
                        systemImage: "checkmark.circle",
                        description: Text("Cuando compartas un gasto con alguien, aparecerá aquí hasta que se pague.")
                    )
                } else {
                    ForEach(viewModel.balances) { balance in
                        Section {
                            ForEach(balance.items) { share in
                                row(share)
                            }
                        } header: {
                            header(for: balance)
                        }
                    }
                }
            }
            .navigationTitle("Compartidos")
            .task { await viewModel.load() }
            .errorAlert($viewModel.alert)
        }
    }

    private func header(for balance: PersonBalance) -> some View {
        let amount = CurrencyFormatter.string(
            fromCents: abs(balance.netCents),
            currency: balance.items.first?.expense.currency ?? CurrencyFormatter.defaultCurrency)
        return HStack {
            Text(verbatim: balance.name)
            Spacer()
            Group {
                if balance.netCents > 0 {
                    Text("Te debe \(amount)").foregroundStyle(.green)
                } else if balance.netCents < 0 {
                    Text("Le debes \(amount)").foregroundStyle(.orange)
                } else {
                    Text("A mano")
                }
            }
            .monospacedDigit()
        }
    }

    private func totalTile(title: LocalizedStringKey, cents: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            Text(CurrencyFormatter.string(fromCents: cents))
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

    private func row(_ share: PendingShare) -> some View {
        let theyOweMe = share.debt.direction == .theyOweMe
        return HStack(spacing: 12) {
            CategoryIcon(
                icon: share.expense.category?.icon ?? "tag",
                colorHex: share.expense.category?.colorHex ?? "#8E8E93",
                size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: share.expense.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Text(share.expense.spentAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(fromCents: share.debt.amountCents, currency: share.expense.currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(verbatim: share.debt.direction.displayName)
                    .font(.caption)
                    .foregroundStyle(theyOweMe ? .green : .orange)
            }
            Button {
                Task { await viewModel.markPaid(share) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Marcar como pagado")
        }
        .swipeActions(edge: .trailing) {
            Button {
                Task { await viewModel.markPaid(share) }
            } label: {
                Label("Pagado", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Marcar como pagado") {
            Task { await viewModel.markPaid(share) }
        }
    }
}
