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
        private var controlObservers: [NSObjectProtocol] = []

        func installControls(on view: IOSVideoPlayerView) {
            controlledView = view
            let nc = NotificationCenter.default

            controlObservers.append(nc.addObserver(forName: .atxKSTogglePlay, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            })

            controlObservers.append(nc.addObserver(forName: .atxKSSeekBack, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                let target = max(0, player.currentPlaybackTime - 10)
                player.seek(time: target) { _ in }
            })

            controlObservers.append(nc.addObserver(forName: .atxKSSeekForward, object: nil, queue: .main) { [weak self] _ in
                guard let player = self?.controlledView?.playerLayer?.player else { return }
                let target = player.currentPlaybackTime + 10
                player.seek(time: target) { _ in }
            })
        }

        deinit {
            controlObservers.forEach { NotificationCenter.default.removeObserver($0) }
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
        context.coordinator.installControls(on: view)
        return view
    }

    func updateUIView(_ uiView: IOSVideoPlayerView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        uiView.set(resource: resource)
    }
}
