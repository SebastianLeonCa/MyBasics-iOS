import SwiftUI

struct CategoriesView: View {
    @State private var viewModel: CategoriesViewModel
    @State private var showingNew = false

    init(repository: any CategoryRepository) {
        _viewModel = State(initialValue: CategoriesViewModel(repository: repository))
    }

    var body: some View {
        List {
            if let loadError = viewModel.loadError {
                LoadErrorView(message: loadError) { await viewModel.load() }
            } else if !viewModel.hasLoaded {
                SkeletonRows(count: 4)
            }
            ForEach(viewModel.categories) { category in
                HStack(spacing: 12) {
                    CategoryIcon(category: category, size: 32)
                    Text(verbatim: category.displayName)
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
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showingNew) {
            NewCategoryView { category in
                try await viewModel.add(category)
            }
        }
    }
}
