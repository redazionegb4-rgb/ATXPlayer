import SwiftUI
import UIKit
import VLCKit

struct VLCFallbackPlayerView: UIViewRepresentable {
    let url: URL
    var onFailure: (() -> Void)? = nil

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private var mediaPlayer: VLCMediaPlayer?
        private var loadedURL: URL?
        var onFailure: (() -> Void)?

        func load(_ url: URL, drawable: UIView) {
            if mediaPlayer == nil {
                let p = VLCMediaPlayer()
                p.delegate = self
                mediaPlayer = p
            }
            guard let p = mediaPlayer else { return }
            p.drawable = drawable
            guard loadedURL != url else {
                if !p.isPlaying { p.play() }
                return
            }
            loadedURL = url
            p.stop()
            p.media = VLCMedia(url: url)
            p.play()
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            if mediaPlayer?.state == .error {
                DispatchQueue.main.async { [weak self] in self?.onFailure?() }
            }
        }

        func stop() {
            mediaPlayer?.stop()
            mediaPlayer?.drawable = nil
            mediaPlayer?.delegate = nil
            mediaPlayer = nil
        }
        deinit { stop() }
    }

    func makeCoordinator() -> Coordinator {
        let c=Coordinator(); c.onFailure=onFailure; return c
    }
    func makeUIView(context: Context) -> UIView {
        let v=UIView(); v.backgroundColor=.black
        context.coordinator.load(url, drawable:v); return v
    }
    func updateUIView(_ uiView:UIView, context:Context) {
        context.coordinator.onFailure=onFailure
        context.coordinator.load(url, drawable:uiView)
    }
    static func dismantleUIView(_ uiView:UIView, coordinator:Coordinator) { coordinator.stop() }
}
