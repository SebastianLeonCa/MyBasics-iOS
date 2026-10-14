import SwiftUI

/// Formulario para crear una categoría: nombre, color e ícono.
struct NewCategoryView: View {
    let onSave: (Category) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = Self.palette[0]
    @State private var icon = Self.icons[0]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    static let palette = [
        "#FF6B35", "#FF006E", "#E63946", "#FFBE0B", "#8AC926", "#2EC4B6",
        "#06D6A0", "#3A86FF", "#5E60CE", "#8338EC", "#B5838D", "#8E8E93",
    ]

    static let icons = [
        "tag", "fork.knife", "cup.and.saucer", "cart", "bag", "car", "bus", "fuelpump",
        "house", "bolt", "drop", "wifi", "cross.case", "pills", "heart", "gamecontroller",
        "film", "music.note", "book", "graduationcap", "pawprint", "gift", "airplane", "tshirt",
    ]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategoryIcon(icon: icon, colorHex: colorHex, size: 44)
                        TextField("Nombre", text: $name)
                            .font(.title3)
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Ícono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button {
                                icon = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(symbol == icon ? .white : .primary)
                                    .background(
                                        symbol == icon ? (Color(hex: colorHex) ?? .gray) : Color.secondary.opacity(0.12),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                            .accessibilityAddTraits(symbol == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty || isSaving)
                }
            }
            .onAppear { nameFocused = true }
            .alert(
                "No se pudo crear la categoría",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await onSave(Category(name: trimmedName, colorHex: colorHex, icon: icon))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
