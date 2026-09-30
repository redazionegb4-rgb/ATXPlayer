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
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.red.opacity(0.18), .clear], center: .center, startRadius: 20, endRadius: 360).ignoresSafeArea()
            VStack(spacing: 20) {
                BrandMark(size: 118)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.78)
                    .opacity(appeared ? 1 : 0)
                Text("ATX PLAYER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                Capsule().fill(Color.red).frame(width: appeared ? 96 : 20, height: 4)
                    .animation(.easeOut(duration: 0.55), value: appeared)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.68, dampingFraction: 0.76)) { appeared = true } }
        .transition(.opacity)
    }
}

struct BrandMark: View {
    var size: CGFloat = 88
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(red: 0.035, green: 0.035, blue: 0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            Text("A")
                .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 1.0, green: 0.10, blue: 0.18), Color(red: 0.68, green: 0.0, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .tracking(-3)
        }
        .frame(width: size, height: size)
    }
}

struct LoginView: View {
    @EnvironmentObject var session: AppSession
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(colors: [Color.red.opacity(0.14), .clear, Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Circle().fill(Color.red.opacity(0.18)).frame(width: 310).blur(radius: 80).offset(x: 155, y: -280)
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 62)
                    BrandMark(size: 92).scaleEffect(appeared || reduceMotion ? 1 : 0.8).opacity(appeared ? 1 : 0)
                    Text("ATX PLAYER").font(.system(size: 34, weight: .black, design: .rounded)).tracking(3).foregroundStyle(.white).padding(.top, 22)
                    Text("Attiva il tuo dispositivo").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.65)).padding(.top, 8)

                    VStack(spacing: 18) {
                        Text("CODICE DISPOSITIVO").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.white.opacity(0.5))
                        Text(session.deviceCode).font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
                        Button {
                            let raw = session.deviceCode
                            let codeOnly = raw.uppercased().hasPrefix("ATX-") ? String(raw.dropFirst(4)) : raw
                            UIPasteboard.general.string = codeOnly
                        } label: {
                            Label("COPIA CODICE", systemImage: "doc.on.doc").font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.9))
                        }
                        Divider().overlay(.white.opacity(0.12))
                        Text("Comunica questo codice al tuo fornitore. Quando la linea è stata caricata, premi Ricarica.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
                        Button { Task { await session.reloadRemoteAccess() } } label: {
                            HStack(spacing: 11) {
                                if session.isLoading { ProgressView().tint(.white) } else { Image(systemName: "arrow.clockwise") }
                                Text(session.isLoading ? "CONTROLLO…" : "RICARICA")
                            }.font(.headline.weight(.bold)).tracking(1).frame(maxWidth: .infinity).padding(.vertical, 17).foregroundStyle(.white)
                             .background(LinearGradient(colors: [Color.red, Color(red: 0.72, green: 0, blue: 0.05)], startPoint: .leading, endPoint: .trailing))
                             .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }.disabled(session.isLoading)
                    }
                    .padding(22).background(.white.opacity(0.055)).overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)).padding(.horizontal, 24).padding(.top, 34)

                    if let error = session.errorMessage { Label(error, systemImage: "exclamationmark.triangle.fill").font(.footnote.weight(.medium)).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 18) }
                    Text("Player multimediale per contenuti autorizzati").font(.caption).foregroundStyle(.white.opacity(0.35)).padding(.top, 30).padding(.bottom, 32)
                }
            }
        }.onAppear { withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.7)) { appeared = true } }
    }
}
