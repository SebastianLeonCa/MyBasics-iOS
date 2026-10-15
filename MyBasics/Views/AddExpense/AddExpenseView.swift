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
                TextField("Persona", text: $viewModel.debtPerson)
                    .textContentType(.name)
                    .focused($focusedField, equals: .debtPerson)

                HStack(spacing: 4) {
                    Text("Monto")
                    Spacer()
                    Text(CurrencyFormatter.symbol(for: viewModel.currency))
                        .foregroundStyle(.secondary)
                    TextField(amountPlaceholder, text: Binding(
                        get: { viewModel.debtAmountText },
                        set: { viewModel.setDebtAmountText($0) }
                    ))
                    .keyboardType(viewModel.usesDecimals ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($focusedField, equals: .debtAmount)
                    .accessibilityLabel("Monto compartido")
                }

                PillPicker(options: DebtDirection.allCases, selection: $viewModel.debtDirection, title: \.displayName)
                    .accessibilityLabel("¿Quién le debe a quién?")
            } label: {
                Label("Compartido con alguien", systemImage: "person.2")
            }
        } footer: {
            if viewModel.hasDebt && !viewModel.isDebtValid {
                Text("Indica la persona y un monto mayor que 0 y no mayor al gasto.")
                    .foregroundStyle(.red)
            } else if viewModel.hasDebt {
                Text("Aparecerá en Compartidos hasta que lo marques como pagado.")
            }
        }
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
