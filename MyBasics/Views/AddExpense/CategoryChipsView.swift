import SwiftUI

/// Chips horizontales de categorías + chip "+ Nueva".
struct CategoryChipsView: View {
    let categories: [Category]
    @Binding var selection: UUID?
    let onNew: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        chip(for: category).id(category.id)
                    }
                    newChip
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: selection) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear {
                if let selection { proxy.scrollTo(selection, anchor: .center) }
            }
        }
    }

    private func chip(for category: Category) -> some View {
        let isSelected = category.id == selection
        let color = Color(hex: category.colorHex) ?? .gray
        return Button {
            withAnimation(.snappy) { selection = category.id }
        } label: {
            Label(category.displayName, systemImage: category.icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? color : Theme.surfaceRaised, in: Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var newChip: some View {
        Button(action: onNew) {
            Label("Nueva", systemImage: "plus")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])))
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nueva categoría")
    }
}
