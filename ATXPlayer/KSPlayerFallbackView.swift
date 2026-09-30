import SwiftUI
import UIKit
import KSPlayer

struct KSPlayerFallbackView: UIViewRepresentable {
    let url: URL
    let title: String
    let onBack: () -> Void

    final class Coordinator {
        var loadedURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configurePlayer(_ view: IOSVideoPlayerView) {
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
    }

    func makeUIView(context: Context) -> IOSVideoPlayerView {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        let view = IOSVideoPlayerView()
        configurePlayer(view)

        view.backBlock = {
            DispatchQueue.main.async {
                onBack()
            }
        }

        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        view.set(resource: resource)

        return view
    }

    func updateUIView(_ uiView: IOSVideoPlayerView, context: Context) {
        configurePlayer(uiView)

        guard context.coordinator.loadedURL != url else {
            return
        }

        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: title)
        uiView.set(resource: resource)
    }
}
