import SwiftUI

/// Hoja para crear o editar un gasto. Pensada para registrar un gasto en menos de 10 segundos:
/// monto con foco automático → tocar categoría → Guardar.
struct AddExpenseView: View {
    @State private var viewModel: AddExpenseViewModel
    let onSaved: (Expense) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var showingNewCategory = false

    private enum Field { case amount, note, debtPerson, debtAmount }

    init(viewModel: AddExpenseViewModel, onSaved: @escaping (Expense) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection

                Section("Categoría") {
                    CategoryChipsView(
                        categories: viewModel.categories,
                        selection: $viewModel.categoryId,
                        onNew: { showingNewCategory = true }
                    )
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    Picker("Tipo", selection: $viewModel.kind) {
                        ForEach(ExpenseKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    TextField("Descripción (opcional)", text: $viewModel.note)
                        .focused($focusedField, equals: .note)
                        .submitLabel(.done)

                    DatePicker("Fecha", selection: $viewModel.spentAt, in: ...Date.now)
                        .foregroundStyle(.secondary)
                }

                debtSection
            }
            .navigationTitle(viewModel.title)
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
            .alert(
                "Algo salió mal",
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var amountSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormatter.symbol(for: viewModel.currency))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
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

                Picker("¿Quién le debe a quién?", selection: $viewModel.debtDirection) {
                    ForEach(DebtDirection.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
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
        Task {
            if let saved = await viewModel.save() {
                onSaved(saved)
                dismiss()
            }
        }
    }
}
