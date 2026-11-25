import SwiftUI

/// Exporta los gastos de un mes a CSV y los comparte (Archivos, Mail, AirDrop, Numbers…).
struct ExportView: View {
    @State private var viewModel: ExportViewModel
    @Environment(\.currency) private var currency

    init(repository: any ExpenseRepository) {
        _viewModel = State(initialValue: ExportViewModel(repository: repository))
    }

    var body: some View {
        List {
            Group {
                Section {
                    MonthNavigator(
                        title: viewModel.monthTitle,
                        canGoForward: viewModel.canGoToNextMonth,
                        onPrevious: viewModel.showPreviousMonth,
                        onNext: viewModel.showNextMonth
                    )
                }

                Section {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Preparando archivo…").foregroundStyle(.secondary)
                        }
                    } else if let error = viewModel.loadError {
                        LoadErrorView(message: error) { await viewModel.prepare(currency: currency) }
                    } else if let url = viewModel.fileURL {
                        LabeledContent("Gastos", value: "\(viewModel.expenses.count)")
                        LabeledContent("Total") {
                            Text(CurrencyFormatter.string(
                                fromCents: ExpenseAnalytics.total(viewModel.expenses), currency: currency))
                                .monospacedDigit()
                        }
                        ShareLink(item: url, preview: SharePreview(viewModel.fileName, image: Image(systemName: "tablecells"))) {
                            Label("Compartir \(viewModel.fileName)", systemImage: "square.and.arrow.up")
                        }
                        .fontWeight(.semibold)
                    } else {
                        Text("No hay gastos en este mes.")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Se abre en Numbers, Excel o Google Sheets. Los montos usan punto decimal.")
                }
            }
            .themedRows()
        }
        .navigationTitle("Exportar CSV")
        .themedScreen()
        // Se rehace el archivo si cambia el mes o la moneda.
        .task(id: "\(viewModel.month.timeIntervalSince1970)-\(currency)") { await viewModel.prepare(currency: currency) }
    }
}
