import SwiftUI
import UIKit
import KSPlayer

struct KSPlayerFallbackView: UIViewRepresentable {
    let url: URL
    let title: String
    let onBack: () -> Void

    final class Coordinator {
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


    private func normalizeSinglePlayerUI(_ root: UIView) {
        root.backgroundColor = .black
        root.clipsToBounds = true

        func walk(_ view: UIView) {
            if let button = view as? UIButton {
                let text = [
                    button.accessibilityIdentifier,
                    button.accessibilityLabel,
                    button.currentTitle
                ]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")

                // PlayerScreen is already true fullscreen. Suppress KSPlayer's second fullscreen
                // presentation path, which can detach/recreate the player and interrupt audio.
                if text.contains("fullscreen") ||
                   text.contains("full screen") ||
                   text.contains("enter full") ||
                   text.contains("exit full") {
                    button.isHidden = true
                    button.isUserInteractionEnabled = false
                }
            }
            view.subviews.forEach(walk)
        }
        walk(root)
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
        normalizeSinglePlayerUI(view)
        return view
    }

    func updateUIView(_ uiView: IOSVideoPlayerView, context: Context) {
        normalizeSinglePlayerUI(uiView)
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        uiView.set(resource: resource)
    }
}
