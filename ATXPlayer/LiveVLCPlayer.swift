import SwiftUI
import UIKit

#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

/// Seleziona il motore impostato dall'utente esclusivamente per i canali Live.
/// Film, serie e download continuano a usare AVPlayer.
struct LivePlayerRouter: View {
    @EnvironmentObject private var session: AppSession
    let title: String
    let url: URL?

    var body: some View {
        Group {
            if session.livePlayerEngine == "vlc" {
                VLCPlayerScreen(title: title, url: url)
            } else {
                PlayerScreen(title: title, url: url, isLive: true)
            }
        }
    }
}

#if canImport(MobileVLCKit)
struct VLCPlayerScreen: View {
    let title: String
    let url: URL?
    @State private var retryToken = UUID()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                VLCVideoSurface(url: url, retryToken: retryToken)
                    .id(retryToken)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                EmptyStateView(
                    title: "Riproduzione non disponibile",
                    icon: "play.slash",
                    message: "Il collegamento del canale non è valido."
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    retryToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Ricarica diretta")
            }
        }
    }
}

private struct VLCVideoSurface: UIViewRepresentable {
    let url: URL
    let retryToken: UUID

    final class Coordinator: NSObject {
        let player: VLCMediaPlayer

        override init() {
            player = VLCMediaPlayer(options: [
                "--network-caching=150",
                "--live-caching=150",
                "--clock-jitter=0",
                "--clock-synchro=0",
                "--drop-late-frames",
                "--skip-frames"
            ])
            super.init()
        }

        func start(url: URL, drawable: UIView) {
            player.stop()
            player.drawable = drawable
            let media = VLCMedia(url: url)
            media.addOption(":network-caching=150")
            media.addOption(":live-caching=150")
            media.addOption(":http-reconnect=true")
            media.addOption(":clock-jitter=0")
            media.addOption(":clock-synchro=0")
            player.media = media
            player.play()
        }

        func stop() {
            player.stop()
            player.drawable = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        context.coordinator.start(url: url, drawable: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if context.coordinator.player.drawable == nil {
            context.coordinator.start(url: url, drawable: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }
}
#else
/// Fallback di sicurezza: il progetto resta compilabile anche prima che CocoaPods
/// abbia risolto MobileVLCKit. Con il pod installato viene usato VLC realmente.
struct VLCPlayerScreen: View {
    let title: String
    let url: URL?

    var body: some View {
        PlayerScreen(title: title, url: url, isLive: true)
            .navigationTitle(title)
    }
}
#endif
