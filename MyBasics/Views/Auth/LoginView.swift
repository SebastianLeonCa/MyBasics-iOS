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
                socialButtons
                divider
                emailForm
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                .accessibilityHidden(true)
            Text(verbatim: "MyBasics")
                .font(.largeTitle.weight(.bold))
            Text("Tus gastos del día a día, en segundos.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var socialButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(viewModel.mode == .signUp ? .signUp : .continue) { request in
                viewModel.prepare(request)
            } onCompletion: { result in
                Task { await viewModel.completeApple(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if viewModel.supportsGoogle {
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
            Rectangle().fill(.separator).frame(height: 1)
            Text("o con tu email")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle().fill(.separator).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var emailForm: some View {
        VStack(spacing: 14) {
            Picker("Modo", selection: $viewModel.mode.animation()) {
                Text("Iniciar sesión").tag(LoginViewModel.Mode.signIn)
                Text("Crear cuenta").tag(LoginViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)

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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            if viewModel.mode == .signUp {
                Label("Mínimo \(LoginViewModel.minimumPasswordLength) caracteres.",
                      systemImage: viewModel.isPasswordValid ? "checkmark.circle.fill" : "circle")
                    .font(.footnote)
                    .foregroundStyle(viewModel.isPasswordValid ? Color.green : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let info = viewModel.infoMessage {
                Label(info, systemImage: "envelope.badge")
                    .font(.callout)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            }

            Button {
                focused = nil
                Task { await viewModel.submit() }
            } label: {
                Text(viewModel.mode == .signUp ? "Crear cuenta" : "Iniciar sesión")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(!viewModel.canSubmit)

            if viewModel.mode == .signIn {
                Button("¿Olvidaste tu contraseña?") {
                    focused = nil
                    Task { await viewModel.sendPasswordReset() }
                }
                .font(.subheadline)
            }
        }
    }
}

#Preview {
    let env = AppEnvironment.mock(signedIn: false)
    return LoginView(environment: env).environment(env)
}
