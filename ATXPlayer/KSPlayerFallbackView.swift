import SwiftUI
import UIKit
import KSPlayer

struct KSPlayerFallbackView: UIViewRepresentable {
    let url: URL
    let title: String
    let onBack: () -> Void

    final class Coordinator: NSObject {
        var loadedURL: URL?

        weak var controlledView: IOSVideoPlayerView?
        private var observers: [NSObjectProtocol] = []

        func attachControls(to view: IOSVideoPlayerView) {
            controlledView = view
            let nc = NotificationCenter.default
            observers.append(nc.addObserver(forName: .atxPlayerTogglePlayback, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                if player.isPlaying { player.pause() } else { player.play() }
            })
            observers.append(nc.addObserver(forName: .atxPlayerSeekBackward, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                player.seek(time: max(0, player.currentPlaybackTime - 10))
            })
            observers.append(nc.addObserver(forName: .atxPlayerSeekForward, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                player.seek(time: player.currentPlaybackTime + 10)
            })
            observers.append(nc.addObserver(forName: .atxPlayerTogglePiP, object: nil, queue: .main) { [weak self] _ in
                self?.controlledView?.playerLayer?.player?.isPipActive.toggle()
            })
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> IOSVideoPlayerView {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        let view = IOSVideoPlayerView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit

        // Use KSPlayer's complete native control surface.
        // Its own back button is the only back button shown in PlayerScreen.
        view.backBlock = {
            DispatchQueue.main.async {
                onBack()
            }
        }

        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        view.set(resource: resource)
        context.coordinator.attachControls(to: view)
        return view
    }

    func updateUIView(_ uiView: IOSVideoPlayerView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        uiView.set(resource: resource)
    }
}
