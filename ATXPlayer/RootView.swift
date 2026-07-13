import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AppSession
    var body: some View {
        Group { session.isAuthenticated ? AnyView(MainTabView()) : AnyView(LoginView()) }
            .animation(.easeInOut(duration: 0.35), value: session.isAuthenticated)
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
    @FocusState private var focused: Field?
    @State private var showPassword = false
    enum Field { case username, password }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.03, blue: 0.075).ignoresSafeArea()
            LinearGradient(colors: [.purple.opacity(0.34), .clear, .cyan.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(.purple.opacity(0.32)).frame(width: 310).blur(radius: 80).offset(x: 155, y: -280)
            Circle().fill(.cyan.opacity(0.15)).frame(width: 260).blur(radius: 90).offset(x: -170, y: 330)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 72)
                    BrandMark(size: 92)
                    Text("ATLANTIX")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .white, .purple], startPoint: .leading, endPoint: .trailing))
                        .padding(.top, 22)
                    Text("Il tuo mondo. Tutto in streaming.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 7)

                    VStack(spacing: 16) {
                        fieldContainer(icon: "person.fill") {
                            TextField("Username", text: $session.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focused, equals: .username)
                        }
                        fieldContainer(icon: "lock.fill") {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $session.password)
                                } else {
                                    SecureField("Password", text: $session.password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .password)
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Button {
                            focused = nil
                            Task { await session.signIn() }
                        } label: {
                            HStack(spacing: 11) {
                                if session.isLoading { ProgressView().tint(.white) }
                                else { Image(systemName: "play.fill") }
                                Text(session.isLoading ? "Connessione in corso…" : "ENTRA")
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
                        .disabled(session.isLoading)
                    }
                    .padding(22)
                    .background(.white.opacity(0.055))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 38)

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
    }

    private func fieldContainer<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.55)).frame(width: 22)
            content()
        }
        .foregroundStyle(.white)
        .padding(17)
        .background(.black.opacity(0.24))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.11)))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}
