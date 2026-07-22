import SwiftUI
import UIKit

#if canImport(MobileVLCKit)
import MobileVLCKit

struct LiveVLCPlayerScreen: View {
    let title: String
    let url: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                LiveVLCPlayerView(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 42))
                    Text("Riproduzione non disponibile")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LiveVLCPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> LiveVLCViewController {
        LiveVLCViewController(url: url)
    }

    func updateUIViewController(_ controller: LiveVLCViewController, context: Context) {
        controller.updateURLIfNeeded(url)
    }

    static func dismantleUIViewController(_ controller: LiveVLCViewController, coordinator: Void) {
        controller.stopPlayback()
    }
}

final class LiveVLCViewController: UIViewController, VLCMediaPlayerDelegate {
    private let videoView = UIView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private var mediaPlayer: VLCMediaPlayer?
    private var currentURL: URL
    private var retryWorkItems: [DispatchWorkItem] = []

    init(url: URL) {
        self.currentURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureViews()
        startPlayback()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mediaPlayer?.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    func updateURLIfNeeded(_ url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        startPlayback()
    }

    private func configureViews() {
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.backgroundColor = .black
        view.addSubview(videoView)

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.color = .white
        loadingView.startAnimating()
        view.addSubview(loadingView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Avvio diretta…"
        statusLabel.textColor = .white
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -18),
            statusLabel.topAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func startPlayback() {
        stopPlayback()
        loadingView.startAnimating()
        statusLabel.isHidden = false

        let options = [
            "--network-caching=120",
            "--live-caching=120",
            "--file-caching=120",
            "--clock-jitter=0",
            "--clock-synchro=0",
            "--drop-late-frames",
            "--skip-frames",
            "--no-video-title-show"
        ]

        let player = VLCMediaPlayer(options: options)
        player.delegate = self
        player.drawable = videoView

        let media = VLCMedia(url: currentURL)
        media.addOptions([
            "network-caching": 120,
            "live-caching": 120,
            "file-caching": 120,
            "clock-jitter": 0,
            "clock-synchro": 0
        ])
        player.media = media
        mediaPlayer = player
        player.play()
        scheduleRecovery(for: player)
    }

    private func scheduleRecovery(for player: VLCMediaPlayer) {
        retryWorkItems.forEach { $0.cancel() }
        retryWorkItems.removeAll()

        for delay in [0.18, 0.55, 1.15] {
            let item = DispatchWorkItem { [weak self, weak player] in
                guard let self, let player, self.mediaPlayer === player else { return }
                if !player.isPlaying {
                    player.play()
                }
            }
            retryWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    func stopPlayback() {
        retryWorkItems.forEach { $0.cancel() }
        retryWorkItems.removeAll()
        mediaPlayer?.delegate = nil
        mediaPlayer?.stop()
        mediaPlayer?.drawable = nil
        mediaPlayer = nil
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = mediaPlayer else { return }
        switch player.state {
        case .playing:
            loadingView.stopAnimating()
            statusLabel.isHidden = true
        case .buffering, .opening:
            loadingView.startAnimating()
            statusLabel.isHidden = false
        case .error:
            loadingView.stopAnimating()
            statusLabel.text = "Canale temporaneamente non disponibile"
            statusLabel.isHidden = false
        default:
            break
        }
    }
}

#else

// Fallback compilabile prima di eseguire `pod install`.
// Dopo l'installazione di MobileVLCKit verrà usato automaticamente VLC.
struct LiveVLCPlayerScreen: View {
    let title: String
    let url: URL?

    var body: some View {
        PlayerScreen(title: title, url: url, isLive: true)
    }
}

#endif
