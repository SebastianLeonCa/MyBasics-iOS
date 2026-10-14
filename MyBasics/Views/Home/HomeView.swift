import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let currency: String
    let onEdit: (Expense) -> Void
    let onAdd: () -> Void

    @State private var pendingDelete: Expense?

    var body: some View {
        NavigationStack {
            List {
                summarySection

                if viewModel.hasLoaded && viewModel.filteredExpenses.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.daySections) { section in
                        Section {
                            ForEach(section.expenses) { expense in
                                ExpenseRow(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onEdit(expense) }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            pendingDelete = expense
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                        .tint(.red)

                                        Button {
                                            onEdit(expense)
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .accessibilityAction(named: "Editar") { onEdit(expense) }
                                    .accessibilityAction(named: "Eliminar") { pendingDelete = expense }
                            }
                        } header: {
                            HStack {
                                Text(ExpenseAnalytics.dayTitle(for: section.day))
                                Spacer()
                                Text(CurrencyFormatter.string(fromCents: section.totalCents, currency: currency))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 8, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: viewModel.month) { await viewModel.load() }
            .confirmationDialog(
                "¿Eliminar este gasto?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { expense in
                Button("Eliminar", role: .destructive) {
                    Task { await viewModel.delete(expense) }
                }
                Button("Cancelar", role: .cancel) {}
            } message: { expense in
                Text("\(expense.displayTitle) · \(CurrencyFormatter.string(fromCents: expense.amountCents, currency: expense.currency))")
            }
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

    // MARK: - Resumen (mes, filtro, gráfico, leyenda)

    private var summarySection: some View {
        Section {
            VStack(spacing: 16) {
                MonthNavigator(
                    title: viewModel.monthTitle,
                    canGoForward: viewModel.canGoToNextMonth,
                    onPrevious: { withAnimation(.smooth) { viewModel.showPreviousMonth() } },
                    onNext: { withAnimation(.smooth) { viewModel.showNextMonth() } }
                )

                Picker("Tipo de gasto", selection: Binding(
                    get: { viewModel.filter },
                    set: { newValue in withAnimation(.smooth) { viewModel.filter = newValue } }
                )) {
                    ForEach(KindFilter.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if viewModel.categoryTotals.isEmpty {
                    emptyDonut
                } else {
                    DonutChartView(
                        totals: viewModel.categoryTotals,
                        totalCents: viewModel.totalCents,
                        currency: currency,
                        selectedCategoryId: viewModel.selectedCategoryId,
                        onSelect: viewModel.toggleSelection
                    )

                    CategoryLegendView(
                        totals: viewModel.categoryTotals,
                        currency: currency,
                        selectedCategoryId: viewModel.selectedCategoryId,
                        onSelect: viewModel.toggleSelection
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// Anillo gris con $0 cuando no hay datos, para que la pantalla no "salte".
    private var emptyDonut: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 36)
                .padding(18)
            VStack(spacing: 2) {
                Text("Total").font(.subheadline).foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(fromCents: 0, currency: currency))
                    .font(.title2.weight(.bold))
            }
        }
        .frame(height: 240)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        Section {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: "sparkles")
            } description: {
                Text("Toca + para registrar tu primer gasto. Te toma menos de 10 segundos.")
            } actions: {
                Button("Agregar gasto", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyTitle: String {
        switch viewModel.filter {
        case .all: String(localized: "Sin gastos este mes")
        case .fixed: String(localized: "Sin gastos fijos este mes")
        case .variable: String(localized: "Sin gastos variables este mes")
        }
    }
}

#Preview {
    let env = AppEnvironment.mock()
    return HomeView(
        viewModel: HomeViewModel(repository: env.expenseRepository),
        currency: "USD", onEdit: { _ in }, onAdd: {}
    )
    .environment(env)
}
