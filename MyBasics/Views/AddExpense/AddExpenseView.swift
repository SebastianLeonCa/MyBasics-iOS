import SwiftUI

/// Hoja para crear o editar un gasto. Pensada para registrar un gasto en menos de 10 segundos:
/// monto con foco automático → tocar categoría → Guardar.
struct AddExpenseView: View {
    @State private var viewModel: AddExpenseViewModel
    /// Recibe el gasto armado; quien lo presenta lo guarda (de forma optimista).
    let onSubmit: (Expense) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var showingNewCategory = false

    private enum Field { case amount, note, debtPerson, debtAmount }

    init(viewModel: AddExpenseViewModel, onSubmit: @escaping (Expense) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    amountSection

                    Section("Categoría") {
                        if let error = viewModel.categoriesError, viewModel.categories.isEmpty {
                            HStack {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Reintentar") { Task { await viewModel.loadCategories() } }
                                    .buttonStyle(.borderless)
                            }
                        } else if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Cargando categorías")
                        } else {
                            CategoryChipsView(
                                categories: viewModel.categories,
                                selection: $viewModel.categoryId,
                                onNew: { showingNewCategory = true }
                            )
                            .listRowInsets(EdgeInsets())
                        }
                    }

                    Section {
                        PillPicker(options: ExpenseKind.allCases, selection: $viewModel.kind, title: \.displayName)
                            .accessibilityLabel("Tipo")
                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))

                        TextField("Descripción (opcional)", text: $viewModel.note)
                            .focused($focusedField, equals: .note)
                            .submitLabel(.done)

                        DatePicker("Fecha", selection: $viewModel.spentAt, in: ...Date.now)
                            .foregroundStyle(.secondary)
                    }

                    debtSection
                }
                .themedRows()
            }
            .navigationTitle(viewModel.title)
            .themedScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.canSave)
                }
            }
            .task {
                await viewModel.loadCategories()
            }
            .onAppear {
                if !viewModel.isEditing { focusedField = .amount }
            }
            .sheet(isPresented: $showingNewCategory) {
                NewCategoryView { category in
                    try await viewModel.addCategory(category)
                }
            }
            .errorAlert($viewModel.alert)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
        .presentationCornerRadius(28)
    }

    private var amountSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormatter.symbol(for: viewModel.currency))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                TextField(amountPlaceholder, text: Binding(
                    get: { viewModel.amountText },
                    set: { viewModel.setAmountText($0) }
                ))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .keyboardType(viewModel.usesDecimals ? .decimalPad : .numberPad)
                    .focused($focusedField, equals: .amount)
                    .accessibilityLabel("Monto")
            }
            .padding(.vertical, 4)
        }
    }

    private var debtSection: some View {
        Section {
            DisclosureGroup(isExpanded: $viewModel.hasDebt.animation()) {
                // Primero quién le debe a quién: define si hace falta un monto aparte.
                PillPicker(options: DebtDirection.allCases, selection: $viewModel.debtDirection.animation(), title: \.displayName)
                    .accessibilityLabel("¿Quién le debe a quién?")

                TextField("Persona", text: $viewModel.debtPerson)
                    .textContentType(.name)
                    .focused($focusedField, equals: .debtPerson)

                // "Me debe": cuánto de lo que pagaste te van a devolver, y tu parte.
                // "Le debo": no se pide: debes el gasto completo (tu parte).
                if viewModel.debtDirection == .theyOweMe {
                    HStack(spacing: 4) {
                        Text("Te debe")
                        if viewModel.isDebtSettled {
                            Label("Ya te pagó", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.positive)
                                .padding(.leading, 6)
                        }
                        Spacer()
                        Text(CurrencyFormatter.symbol(for: viewModel.currency))
                            .foregroundStyle(Theme.textSecondary)
                        // Vacío muestra la mitad en gris (sugerencia); lo que escribas queda fijo.
                        TextField(debtPlaceholder, text: Binding(
                            get: { viewModel.debtAmountText },
                            set: { viewModel.setDebtAmountText($0) }
                        ))
                        .keyboardType(viewModel.usesDecimals ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.trailing)
                        .fixedSize()
                        .focused($focusedField, equals: .debtAmount)
                        .accessibilityLabel("Monto que te debe")
                    }
                    .transition(.opacity)

                    if let share = viewModel.netAfterReimbursementCents {
                        LabeledContent("Tu parte") {
                            Text(CurrencyFormatter.string(fromCents: share, currency: viewModel.currency))
                                .font(Theme.amount(.body, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .transition(.opacity)
                    }
                }
            } label: {
                Label("Compartido con alguien", systemImage: "person.2")
            }
        } footer: {
            if viewModel.hasDebt && !viewModel.isDebtValid {
                Text("Indica la persona y un monto mayor que 0 y no mayor al gasto.")
                    .foregroundStyle(Theme.negative)
            } else if viewModel.hasDebt {
                debtExplanation
            }
        }
    }

    /// Explica qué pasará al marcarlo como pagado, con los montos reales.
    @ViewBuilder
    private var debtExplanation: some View {
        switch viewModel.debtDirection {
        case .theyOweMe:
            Text("El monto de arriba es el total que pagaste. Cuando te pague, en tus gastos contará solo tu parte.")
        case .iOweThem:
            Text("Registra solo tu parte: ese monto es lo que debes. Al marcarlo como pagado, el gasto se mantiene y sale de lo que debes.")
        }
    }

    /// La sugerencia (la mitad del total) como texto gris del campo.
    private var debtPlaceholder: String {
        viewModel.suggestedDebtCents.map { CurrencyFormatter.inputString(fromCents: $0, currency: viewModel.currency) }
            ?? amountPlaceholder
    }

    /// "0.00" o "0,00" según el dispositivo ("0" si la moneda no usa decimales).
    private var amountPlaceholder: String {
        viewModel.usesDecimals ? "0\(CurrencyFormatter.decimalSeparator())00" : "0"
    }

    private func save() {
        guard viewModel.canSave, let expense = viewModel.makeExpense() else { return }
        onSubmit(expense)
        dismiss()
    }
}
