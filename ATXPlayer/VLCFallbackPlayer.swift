import SwiftUI
import VLCKit

/// Compatibility player used only when AVPlayer cannot open a non-live movie/episode.
/// This adds support for HEVC/H.265 streams and containers not handled by AVFoundation.
struct VLCFallbackPlayerView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        let mediaPlayer = VLCMediaPlayer()
        var loadedURL: URL?

        func load(_ url: URL, drawable: UIView) {
            mediaPlayer.drawable = drawable
            guard loadedURL != url else {
                if !mediaPlayer.isPlaying { mediaPlayer.play() }
                return
            }
            loadedURL = url
            mediaPlayer.stop()
            mediaPlayer.media = VLCMedia(url: url)
            mediaPlayer.play()
        }

        deinit {
            mediaPlayer.stop()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        context.coordinator.load(url, drawable: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.load(url, drawable: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.mediaPlayer.stop()
        coordinator.mediaPlayer.drawable = nil
    }
}
