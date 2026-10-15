import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.currency) private var currency
    let onEdit: (Expense) -> Void
    let onAdd: () -> Void

    @State private var pendingDelete: Expense?

    var body: some View {
        NavigationStack {
            List {
                summarySection

                if let loadError = viewModel.loadError {
                    Section {
                        LoadErrorView(message: loadError) { await viewModel.load() }
                    }
                    .themedRows()
                } else if viewModel.isShowingSkeleton {
                    Section {
                        SkeletonRows()
                    } header: {
                        sectionHeader(Text("Cargando…"))
                    }
                    .themedRows()
                } else if viewModel.filteredExpenses.isEmpty {
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
                            sectionHeader(
                                Text(ExpenseAnalytics.dayTitle(for: section.day)),
                                trailing: CurrencyFormatter.string(fromCents: section.totalCents, currency: currency))
                        }
                        .themedRows()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(14)
            .contentMargins(.top, 4, for: .scrollContent)
            .themedScreen()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: viewModel.month) { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sensoryFeedback(.success, trigger: viewModel.savedFeedback)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.deletedFeedback)
            .sensoryFeedback(.error, trigger: viewModel.errorFeedback)
            .sensoryFeedback(.selection, trigger: viewModel.selectedCategoryId)
            .alert(
                "¿Eliminar este gasto?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { expense in
                Button("Eliminar", role: .destructive) {
                    Task { await viewModel.delete(expense) }
                }
                Button("Cancelar", role: .cancel) {}
            } message: { expense in
                Text("\(expense.displayTitle) · \(CurrencyFormatter.string(fromCents: expense.netAmountCents, currency: currency))")
            }
            .errorAlert($viewModel.alert)
        }
    }

    // MARK: - Resumen (mes, filtro, gráfico, leyenda)

    private var summarySection: some View {
        Section {
            VStack(spacing: 14) {
                MonthNavigator(
                    title: viewModel.monthTitle,
                    canGoForward: viewModel.canGoToNextMonth,
                    onPrevious: { Motion.animate { viewModel.showPreviousMonth() } },
                    onNext: { Motion.animate { viewModel.showNextMonth() } }
                )

                statusLine

                VStack(spacing: 16) {
                PillPicker(
                    options: KindFilter.allCases,
                    selection: Binding(
                        get: { viewModel.filter },
                        set: { newValue in Motion.animate { viewModel.filter = newValue } }),
                    title: \.displayName)
                    .accessibilityLabel("Tipo de gasto")

                if viewModel.isShowingSkeleton {
                    ProgressView()
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Cargando gastos")
                } else if viewModel.categoryTotals.isEmpty {
                    emptyDonut
                } else {
                    DonutChartView(
                        totals: viewModel.categoryTotals,
                        totalCents: viewModel.totalCents,
                        selectedCategoryId: viewModel.selectedCategoryId,
                        onSelect: viewModel.toggleSelection
                    )

                    CategoryLegendView(
                        totals: viewModel.categoryTotals,
                        selectedCategoryId: viewModel.selectedCategoryId,
                        onSelect: viewModel.toggleSelection
                    )
                }
                }
                .card()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    /// Encabezado de sección: texto pequeño y, opcional, un monto a la derecha.
    private func sectionHeader(_ title: Text, trailing: String? = nil) -> some View {
        HStack {
            title
            Spacer()
            if let trailing {
                Text(trailing).font(Theme.amount(.footnote, weight: .semibold))
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
        .textCase(nil)
    }

    /// "Actualizando…" mientras se refresca la caché, o un aviso si se está sin conexión.
    @ViewBuilder
    private var statusLine: some View {
        if viewModel.isShowingCachedData {
            Group {
                if viewModel.isLoading {
                    Label { Text("Actualizando…") } icon: { ProgressView().controlSize(.mini) }
                } else {
                    Label("Sin conexión · mostrando datos guardados", systemImage: "icloud.slash")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .transition(.opacity)
        }
    }

    /// Anillo gris con $0 cuando no hay datos, para que la pantalla no "salte".
    private var emptyDonut: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: 36)
                .padding(18)
            VStack(spacing: 2) {
                Text("Total").font(.subheadline).foregroundStyle(Theme.textSecondary)
                Text(CurrencyFormatter.string(fromCents: 0, currency: currency))
                    .font(Theme.amount(.title2))
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
                    .foregroundStyle(.black)
            }
        }
        .themedRows()
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
        onEdit: { _ in }, onAdd: {}
    )
    .environment(env)
}
