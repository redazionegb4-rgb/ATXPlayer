import SwiftUI
import UIKit
import VLCKitSPM

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

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        let player: VLCMediaPlayer

        private weak var drawableView: UIView?
        private var currentURL: URL?
        private var launchGeneration = UUID()
        private var retryWorkItems: [DispatchWorkItem] = []
        private var activeObserver: NSObjectProtocol?

        override init() {
            player = VLCMediaPlayer(options: [
                "--network-caching=120",
                "--live-caching=120",
                "--clock-jitter=0",
                "--clock-synchro=0",
                "--drop-late-frames",
                "--skip-frames"
            ])
            super.init()
            player.delegate = self

            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.ensurePlaybackStarted()
            }
        }

        deinit {
            if let activeObserver {
                NotificationCenter.default.removeObserver(activeObserver)
            }
            cancelRetries()
        }

        func start(url: URL, drawable: UIView) {
            drawableView = drawable
            currentURL = url
            launchGeneration = UUID()
            let generation = launchGeneration

            cancelRetries()
            player.stop()
            player.drawable = drawable

            // VLC può ignorare il primo play se viene chiamato nello stesso ciclo
            // in cui il player precedente è stato fermato. Impostiamo quindi il
            // media nel ciclo successivo e ripetiamo play finché parte davvero.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.launchGeneration == generation else { return }

                let media = VLCMedia(url: url)
                media.addOption(":network-caching=120")
                media.addOption(":live-caching=120")
                media.addOption(":http-reconnect=true")
                media.addOption(":clock-jitter=0")
                media.addOption(":clock-synchro=0")
                media.addOption(":no-start-paused")

                self.player.media = media
                self.player.play()
                self.scheduleAutoplayRetries(generation: generation)
            }
        }

        private func scheduleAutoplayRetries(generation: UUID) {
            // play() non è un toggle in MobileVLCKit: richiamarlo mentre sta
            // aprendo il flusso è sicuro e impedisce che il Live resti in pausa.
            for delay in [0.12, 0.35, 0.75, 1.30, 2.10] {
                let item = DispatchWorkItem { [weak self] in
                    guard let self,
                          self.launchGeneration == generation,
                          self.currentURL != nil,
                          !self.player.isPlaying else { return }
                    self.player.play()
                }
                retryWorkItems.append(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            }
        }

        private func ensurePlaybackStarted() {
            guard currentURL != nil else { return }
            player.drawable = drawableView
            if !player.isPlaying {
                player.play()
                let generation = launchGeneration
                scheduleAutoplayRetries(generation: generation)
            }
        }

        private func cancelRetries() {
            retryWorkItems.forEach { $0.cancel() }
            retryWorkItems.removeAll()
        }

        func stop() {
            launchGeneration = UUID()
            cancelRetries()
            currentURL = nil
            player.stop()
            player.drawable = nil
            drawableView = nil
        }

        func mediaPlayerStateChanged(_ aNotification: Notification!) {
            // Alcuni server HLS portano VLC nello stato Paused durante l'apertura.
            // Appena VLC comunica un cambio di stato, forziamo nuovamente Play.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentURL != nil else { return }
                if !self.player.isPlaying {
                    self.player.play()
                }
            }
        }

        func mediaPlayerTimeChanged(_ aNotification: Notification!) {
            // Quando il tempo avanza la diretta è realmente partita: i tentativi
            // residui non sono più necessari.
            if player.isPlaying {
                cancelRetries()
            }
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
        context.coordinator.player.drawable = uiView
        if context.coordinator.player.media == nil {
            context.coordinator.start(url: url, drawable: uiView)
        } else if !context.coordinator.player.isPlaying {
            context.coordinator.player.play()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }
}

