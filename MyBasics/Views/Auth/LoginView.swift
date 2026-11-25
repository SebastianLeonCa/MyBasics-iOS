import AuthenticationServices
import SwiftUI

/// Login: Sign in with Apple, Continuar con Google y email + contraseña (con registro y recuperación).
struct LoginView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var viewModel: LoginViewModel
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: LoginViewModel(
            auth: environment.authService,
            googleClientID: environment.googleIOSClientID,
            onSignedIn: { [weak environment] in environment?.syncSession() }))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                // Apple y Google solo aparecen si están configurados; sin ninguno, queda solo el email.
                if hasSocialButtons {
                    socialButtons
                    divider
                }
                emailForm
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ThemedBackground())
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
                    .padding(24)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Iniciando sesión")
            }
        }
        .errorAlert($viewModel.alert)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .shadow(color: Theme.accent.opacity(0.45), radius: 24)
                .accessibilityHidden(true)
            Text(verbatim: "MyBasics")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Tus gastos del día a día, en segundos.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var hasSocialButtons: Bool { env.isAppleSignInEnabled || viewModel.isGoogleConfigured }

    private var socialButtons: some View {
        VStack(spacing: 12) {
            // Solo con APPLE_SIGN_IN = YES (requiere el Apple Developer Program).
            if env.isAppleSignInEnabled {
                SignInWithAppleButton(viewModel.mode == .signUp ? .signUp : .continue) { request in
                    viewModel.prepare(request)
                } onCompletion: { result in
                    Task { await viewModel.completeApple(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Solo con GOOGLE_IOS_CLIENT_ID en Secrets.xcconfig.
            if viewModel.isGoogleConfigured {
                GoogleSignInButton {
                    Task {
                        await viewModel.signInWithGoogle { url, scheme in
                            try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: scheme)
                        }
                    }
                }
            }
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
            Text("o con tu email")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize()
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var emailForm: some View {
        VStack(spacing: 14) {
            PillPicker(options: [LoginViewModel.Mode.signIn, .signUp], selection: $viewModel.mode) { mode in
                mode == .signIn ? String(localized: "Iniciar sesión") : String(localized: "Crear cuenta")
            }

            VStack(spacing: 0) {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focused, equals: .email)
                    .onSubmit { focused = .password }
                    .padding(14)
                Divider().padding(.leading, 14)
                SecureField("Contraseña", text: $viewModel.password)
                    .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                    .submitLabel(.go)
                    .focused($focused, equals: .password)
                    .onSubmit { Task { await viewModel.submit() } }
                    .padding(14)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))

            if viewModel.mode == .signUp {
                Label("Mínimo \(LoginViewModel.minimumPasswordLength) caracteres.",
                      systemImage: viewModel.isPasswordValid ? "checkmark.circle.fill" : "circle")
                    .font(.footnote)
                    .foregroundStyle(viewModel.isPasswordValid ? Theme.positive : Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let info = viewModel.infoMessage {
                Label(info, systemImage: "envelope.badge")
                    .font(.callout)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity)
            }

            Button {
                focused = nil
                Task { await viewModel.submit() }
            } label: {
                Text(viewModel.mode == .signUp ? "Crear cuenta" : "Iniciar sesión")
                    .font(.headline)
                    .foregroundStyle(viewModel.canSubmit ? Color.black : Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(viewModel.canSubmit ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceRaised))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!viewModel.canSubmit)

            if viewModel.mode == .signIn {
                Button("¿Olvidaste tu contraseña?") {
                    focused = nil
                    Task { await viewModel.sendPasswordReset() }
                }
                .font(.subheadline.weight(.medium))
                .tint(Theme.accent)
            }
        }
    }
}

#Preview {
    let env = AppEnvironment.mock(signedIn: false)
    return LoginView(environment: env).environment(env)
}
