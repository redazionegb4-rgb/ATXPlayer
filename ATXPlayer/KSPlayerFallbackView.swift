import SwiftUI
import UIKit
import AVKit
import KSPlayer

final class ATXKSPlayerController: UIViewController {
    private let mediaURL: URL
    private let mediaTitle: String
    var onBack: (() -> Void)?

    // KSPlayer remains ONLY as playback/decoder engine.
    private let videoView = IOSVideoPlayerView()

    // ATX interface: KSPlayer's own toolbar/fullscreen UI is never used.
    private let controls = UIView()
    private let atxTitle = UILabel()
    private let backButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let back10Button = UIButton(type: .system)
    private let forward10Button = UIButton(type: .system)
    private let fullscreenButton = UIButton(type: .system)
    private let routePicker = AVRoutePickerView(frame: .zero)

    private var fullscreen = false

    init(url: URL, title: String) {
        self.mediaURL = url
        self.mediaTitle = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        videoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoView)
        NSLayoutConstraint.activate([
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Critical: never expose KSPlayer's toolbar/fullscreen controls.
        videoView.toolBar.isHidden = true

        buildATXControls()

        let resource = KSPlayerResource(url: mediaURL, name: "")
        videoView.set(resource: resource)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoView.toolBar.isHidden = true
        view.bringSubviewToFront(controls)
    }

    private func buildATXControls() {
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.backgroundColor = .clear
        view.addSubview(controls)

        atxTitle.translatesAutoresizingMaskIntoConstraints = false
        atxTitle.text = mediaTitle
        atxTitle.textColor = .white
        atxTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        atxTitle.textAlignment = .center
        atxTitle.lineBreakMode = .byTruncatingTail
        controls.addSubview(atxTitle)

        configure(backButton, "chevron.left", #selector(closeTapped))
        configure(back10Button, "gobackward.10", #selector(back10Tapped))
        configure(playPauseButton, "pause.fill", #selector(playPauseTapped))
        configure(forward10Button, "goforward.10", #selector(forward10Tapped))
        configure(fullscreenButton, "arrow.up.left.and.arrow.down.right", #selector(fullscreenTapped))

        routePicker.translatesAutoresizingMaskIntoConstraints = false
        routePicker.tintColor = .white
        routePicker.activeTintColor = .white
        routePicker.prioritizesVideoDevices = true

        let bottom = UIStackView(arrangedSubviews: [
            back10Button, playPauseButton, forward10Button, routePicker, fullscreenButton
        ])
        bottom.axis = .horizontal
        bottom.alignment = .center
        bottom.distribution = .equalSpacing
        bottom.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(bottom)

        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: view.topAnchor),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            atxTitle.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            atxTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            atxTitle.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            atxTitle.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -56),

            bottom.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            bottom.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            bottom.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            routePicker.widthAnchor.constraint(equalToConstant: 44),
            routePicker.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configure(_ button: UIButton, _ symbol: String, _ action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.setImage(
            UIImage(systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)),
            for: .normal
        )
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func withPlayer(_ action: (MediaPlayerProtocol) -> Void) {
        guard let layer = videoView.playerLayer else { return }
        action(layer.player)
    }

    @objc private func closeTapped() {
        if fullscreen {
            setFullscreen(false)
        } else {
            onBack?()
        }
    }

    @objc private func playPauseTapped() {
        withPlayer { player in
            if player.isPlaying {
                player.pause()
                self.setPlayIcon(true)
            } else {
                player.play()
                self.setPlayIcon(false)
            }
        }
    }

    @objc private func back10Tapped() {
        withPlayer { player in
            let target = max(0, player.currentPlaybackTime - 10)
            player.seek(time: target) { _ in }
        }
    }

    @objc private func forward10Tapped() {
        withPlayer { player in
            let target = player.currentPlaybackTime + 10
            player.seek(time: target) { _ in }
        }
    }

    private func setPlayIcon(_ showPlay: Bool) {
        let symbol = showPlay ? "play.fill" : "pause.fill"
        playPauseButton.setImage(
            UIImage(systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)),
            for: .normal
        )
    }

    @objc private func fullscreenTapped() {
        setFullscreen(!fullscreen)
    }

    // IMPORTANT:
    // Fullscreen does NOT call KSPlayer's fullscreen implementation and does NOT
    // detach/recreate the video view. The same decoder/player/view stays alive.
    // We only request a scene orientation change.
    private func setFullscreen(_ value: Bool) {
        fullscreen = value
        let mask: UIInterfaceOrientationMask = value ? .landscape : .portrait

        if #available(iOS 16.0, *), let scene = view.window?.windowScene {
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            scene.requestGeometryUpdate(prefs) { _ in }
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        let symbol = value
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        fullscreenButton.setImage(
            UIImage(systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)),
            for: .normal
        )
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        fullscreen ? .landscape : .portrait
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        fullscreen
    }
}

struct KSPlayerFallbackView: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let onBack: () -> Void

    func makeUIViewController(context: Context) -> ATXKSPlayerController {
        let controller = ATXKSPlayerController(url: url, title: title)
        controller.onBack = onBack
        return controller
    }

    func updateUIViewController(_ uiViewController: ATXKSPlayerController, context: Context) {
        uiViewController.onBack = onBack
    }
}
