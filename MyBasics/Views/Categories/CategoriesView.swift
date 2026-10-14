import SwiftUI

struct CategoriesView: View {
    @State private var viewModel: CategoriesViewModel
    @State private var showingNew = false

    init(repository: any CategoryRepository) {
        _viewModel = State(initialValue: CategoriesViewModel(repository: repository))
    }

    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                HStack(spacing: 12) {
                    CategoryIcon(category: category, size: 32)
                    Text(category.name)
                    Spacer()
                    if category.isDefault {
                        Text("Por defecto")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Categorías")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Label("Nueva categoría", systemImage: "plus")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showingNew) {
            NewCategoryView { category in
                try await viewModel.add(category)
            }
        }
    }
}
