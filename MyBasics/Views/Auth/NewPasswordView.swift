import SwiftUI

/// Se abre al tocar el enlace de "olvidé mi contraseña" del correo.
struct NewPasswordView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var alert: UserFacingError?
    @State private var saved = false

    private var isValid: Bool {
        password.count >= LoginViewModel.minimumPasswordLength && password == confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Nueva contraseña", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Repite la contraseña", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    if !confirmation.isEmpty && password != confirmation {
                        Text("Las contraseñas no coinciden.").foregroundStyle(.red)
                    } else {
                        Text("Mínimo \(LoginViewModel.minimumPasswordLength) caracteres.")
                    }
                }
            }
            .navigationTitle("Nueva contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { save() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
            .errorAlert($alert)
            .sensoryFeedback(.success, trigger: saved)
        }
        .presentationDetents([.medium])
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await env.authService.updatePassword(password)
                saved = true
                env.linkMessage = UserFacingError(
                    title: String(localized: "Contraseña actualizada"),
                    message: String(localized: "Ya puedes usarla para iniciar sesión."))
                dismiss()
            } catch {
                alert = UserFacingError(error, title: String(localized: "No se pudo cambiar la contraseña"))
            }
        }
    }
}
