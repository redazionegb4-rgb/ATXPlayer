import SwiftUI
import UIKit
import KSPlayer

struct KSPlayerFallbackView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var loadedURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> IOSVideoPlayerView {
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        let view = IOSVideoPlayerView()
        view.backgroundColor = .black
        context.coordinator.loadedURL = url
        view.set(url: url)
        return view
    }

    func updateUIView(_ uiView: IOSVideoPlayerView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        uiView.set(url: url)
    }
}
