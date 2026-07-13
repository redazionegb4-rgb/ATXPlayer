import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AppSession
    var body: some View {
        Group { if session.isAuthenticated { MainTabView() } else { LoginView() } }
            .animation(.easeInOut(duration: 0.3), value: session.isAuthenticated)
    }
}

struct LoginView: View {
    @EnvironmentObject var session: AppSession
    @FocusState private var focused: Field?
    enum Field { case username, password }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.13), Color(red: 0.18, green: 0.08, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(.purple.opacity(0.28)).frame(width: 340).blur(radius: 70).offset(x: 160, y: -280)
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 80)
                    ZStack {
                        RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial).frame(width: 98, height: 98)
                        Image(systemName: "play.tv.fill").font(.system(size: 46, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(spacing: 8) {
                        Text("ATX Player").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text("Il tuo intrattenimento, in un solo posto").foregroundStyle(.white.opacity(0.68))
                    }
                    VStack(spacing: 15) {
                        input("Username", icon: "person.fill", text: $session.username, secure: false, field: .username)
                        input("Password", icon: "lock.fill", text: $session.password, secure: true, field: .password)
                        Button {
                            focused = nil
                            Task { await session.signIn() }
                        } label: {
                            HStack { if session.isLoading { ProgressView().tint(.white) } else { Image(systemName: "arrow.right.circle.fill") }; Text(session.isLoading ? "Connessione…" : "Accedi") }
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17).background(.white).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 18))
                        }.disabled(session.isLoading)
                    }.padding(.horizontal, 24)
                    if let error = session.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal, 28)
                    }
                    Text("ATX Player non fornisce contenuti. Usa esclusivamente credenziali autorizzate.").font(.caption).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            }
        }
    }

    @ViewBuilder private func input(_ title: String, icon: String, text: Binding<String>, secure: Bool, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.55)).frame(width: 22)
            if secure { SecureField(title, text: text).focused($focused, equals: field) } else { TextField(title, text: text).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused, equals: field) }
        }.foregroundStyle(.white).padding(17).background(.white.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.12)))
    }
}
