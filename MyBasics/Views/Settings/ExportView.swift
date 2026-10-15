import SwiftUI

/// Exporta los gastos de un mes a CSV y los comparte (Archivos, Mail, AirDrop, Numbers…).
struct ExportView: View {
    @State private var viewModel: ExportViewModel
    let currency: String

    init(repository: any ExpenseRepository, currency: String) {
        _viewModel = State(initialValue: ExportViewModel(repository: repository))
        self.currency = currency
    }

    var body: some View {
        List {
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
                    LoadErrorView(message: error) { await viewModel.prepare() }
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
        .navigationTitle("Exportar CSV")
        .task(id: viewModel.month) { await viewModel.prepare() }
    }
}
