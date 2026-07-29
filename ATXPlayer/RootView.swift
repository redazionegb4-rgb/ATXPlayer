import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AppSession
    @State private var showSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Group { session.isAuthenticated ? AnyView(MainTabView()) : AnyView(LoginView()) }
                .opacity(showSplash ? 0 : 1)
                .scaleEffect(showSplash && !reduceMotion ? 0.985 : 1)

            if showSplash { LaunchAnimationView() }
        }
        .preferredColorScheme(.dark)
        .tint(.cyan)
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.45), value: session.isAuthenticated)
        .task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 250_000_000 : 1_350_000_000)
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.45)) { showSplash = false }
        }
    }
}

struct LaunchAnimationView: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.07).ignoresSafeArea()
            RadialGradient(colors: [.purple.opacity(0.42), .clear], center: .center, startRadius: 20, endRadius: 330).ignoresSafeArea()
            VStack(spacing: 22) {
                BrandMark(size: 116)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.72)
                    .opacity(appeared ? 1 : 0)
                Text("ATLANTIX")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(LinearGradient(colors: [.cyan, .white, .purple], startPoint: .leading, endPoint: .trailing))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 12)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { appeared = true } }
        .transition(.opacity)
    }
}

struct BrandMark: View {
    var size: CGFloat = 88
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [Color.cyan, Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .purple.opacity(0.55), radius: 24, y: 10)
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundStyle(.white)
                .offset(x: -2)
        }
        .frame(width: size, height: size)
    }
}

struct LoginView: View {
    @EnvironmentObject var session: AppSession
    @FocusState private var focusedField: Field?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field { case username, password }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.03, blue: 0.075).ignoresSafeArea()
            LinearGradient(colors: [.purple.opacity(0.34), .clear, .cyan.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(.purple.opacity(0.32)).frame(width: 310).blur(radius: 80).offset(x: 155, y: -280)
            Circle().fill(.cyan.opacity(0.15)).frame(width: 260).blur(radius: 90).offset(x: -170, y: 330)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 62)
                    BrandMark(size: 92)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                    Text("ATLANTIX")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white, .purple], startPoint: .leading, endPoint: .trailing))
                        .padding(.top, 22)
                    Text("Accedi con le credenziali del tuo account esistente")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 8)

                    VStack(spacing: 15) {
                        loginField(icon: "person.fill", title: "Nome utente") {
                            TextField("Nome utente", text: $session.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        loginField(icon: "lock.fill", title: "Password") {
                            SecureField("Password", text: $session.password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    focusedField = nil
                                    Task { await session.signIn() }
                                }
                        }

                        Button {
                            focusedField = nil
                            Task { await session.signIn() }
                        } label: {
                            HStack(spacing: 11) {
                                if session.isLoading { ProgressView().tint(.white) }
                                else { Image(systemName: "play.fill") }
                                Text(session.isLoading ? "Accesso in corso…" : "ACCEDI")
                            }
                            .font(.headline.weight(.bold))
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundStyle(.white)
                            .background(LinearGradient(colors: [.purple, .indigo, .cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .purple.opacity(0.38), radius: 20, y: 9)
                        }
                        .disabled(session.isLoading || session.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.password.isEmpty)
                    }
                    .padding(22)
                    .background(.white.opacity(0.055))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 34)
                    .offset(y: appeared || reduceMotion ? 0 : 28)
                    .opacity(appeared ? 1 : 0)

                    if let error = session.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 18)
                    }

                    Text("Player multimediale per contenuti autorizzati")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 30)
                        .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            focusedField = nil
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.7).delay(reduceMotion ? 0 : 0.08)) { appeared = true }
        }
    }

    private func loginField<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.white.opacity(0.55))
            content()
                .foregroundStyle(.white)
        }
        .padding(18)
        .background(.black.opacity(0.24))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.11)))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityLabel(title)
    }
}
