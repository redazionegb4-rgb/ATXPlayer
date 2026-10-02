import SwiftUI
import UIKit
import VLCKit

struct VLCFallbackPlayerView: UIViewRepresentable {
    let url: URL

    final class Coordinator: NSObject {
        var player: VLCMediaPlayer?

        func start(url: URL, view: UIView) {
            if player == nil {
                player = VLCMediaPlayer()
            }
            guard let player else { return }
            player.drawable = view
            if player.media?.url != url {
                player.stop()
                player.media = VLCMedia(url: url)
            }
            if !player.isPlaying {
                player.play()
            }
        }

        func stop() {
            player?.stop()
            player?.drawable = nil
            player = nil
        }

        deinit {
            stop()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        context.coordinator.start(url: url, view: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.start(url: url, view: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }
}
