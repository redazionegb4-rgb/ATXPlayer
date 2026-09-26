import SwiftUI
import UIKit
import MobileVLCKit

/// Decoder di compatibilità usato solo quando AVPlayer riproduce il flusso live
/// ma non riesce a produrre frame video (codec/container non supportato da AVFoundation).
struct VLCFallbackPlayer: UIViewRepresentable {
    let url: URL

    final class Coordinator: NSObject {
        let mediaPlayer = VLCMediaPlayer()
        var currentURL: URL?

        func play(_ url: URL, in view: UIView) {
            guard currentURL != url || mediaPlayer.drawable == nil else { return }
            currentURL = url
            mediaPlayer.stop()
            mediaPlayer.drawable = view
            let media = VLCMedia(url: url)
            // Valori contenuti per una diretta: abbastanza buffer per codec/TS più
            // difficili senza introdurre un ritardo eccessivo.
            media.addOptions([
                "network-caching": 1200,
                "live-caching": 1200,
                "clock-jitter": 0,
                "clock-synchro": 0
            ])
            mediaPlayer.media = media
            mediaPlayer.play()
        }

        func stop() {
            mediaPlayer.stop()
            mediaPlayer.drawable = nil
            currentURL = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true
        context.coordinator.play(url, in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.play(url, in: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }
}
