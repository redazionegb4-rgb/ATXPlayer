import SwiftUI
import UIKit
import KSPlayer

// ATX Player 5.1:
// One playback engine/UI only.
// KSMEPlayer is the FFmpeg-backed engine supplied by KSPlayer.
final class ATXKSPlayerViewController: UIViewController {
    private let mediaURL: URL
    private let mediaTitle: String
    private let isLive: Bool
    private let playerView = IOSVideoPlayerView()

    var onClose: (() -> Void)?

    init(url: URL, title: String, isLive: Bool) {
        self.mediaURL = url
        self.mediaTitle = title
        self.isLive = isLive
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        // IMPORTANT: select FFmpeg/KSMEPlayer as the fallback engine.
        // KSPlayer keeps a single player view and manages its own controls,
        // fullscreen, seeking, tracks and playback state.
        KSOptions.secondPlayerType = KSMEPlayer.self

        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        playerView.backBlock = { [weak self] in
            guard let self else { return }

            // Let KSPlayer exit landscape/fullscreen using its own UI/state.
            if self.view.bounds.width > self.view.bounds.height {
                self.playerView.updateUI(isLandscape: false)
                self.requestPortrait()
            } else {
                self.onClose?()
            }
        }

        let options = KSOptions()
        // A larger probe/analyze window helps MPEG-TS/MKV/HEVC streams whose
        // tracks are not immediately available at the beginning of the file.
        options.isAutoPlay = true

        let definition = KSPlayerResourceDefinition(
            url: mediaURL,
            definition: isLive ? "LIVE" : "AUTO",
            options: options
        )
        let resource = KSPlayerResource(
            name: mediaTitle,
            definitions: [definition]
        )

        playerView.set(resource: resource)
    }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private func requestPortrait() {
        guard #available(iOS 16.0, *),
              let scene = view.window?.windowScene else { return }
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        scene.requestGeometryUpdate(preferences)
    }
}

struct ATXKSPlayerContainer: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let isLive: Bool
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> ATXKSPlayerViewController {
        let controller = ATXKSPlayerViewController(url: url, title: title, isLive: isLive)
        controller.onClose = onClose
        return controller
    }

    func updateUIViewController(_ uiViewController: ATXKSPlayerViewController, context: Context) {
        uiViewController.onClose = onClose
    }
}

struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let url: URL?
    let isLive: Bool
    var resume: PlaybackDescriptor? = nil
    var episodeQueue: [PlaybackQueueItem] = []
    var startIndex: Int = 0

    private var selectedURL: URL? {
        if !episodeQueue.isEmpty, episodeQueue.indices.contains(startIndex) {
            return episodeQueue[startIndex].url
        }
        return url
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let selectedURL {
                ATXKSPlayerContainer(
                    url: selectedURL,
                    title: title,
                    isLive: isLive,
                    onClose: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                    Text("Riproduzione non disponibile")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
