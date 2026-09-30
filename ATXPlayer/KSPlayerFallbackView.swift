import SwiftUI
import UIKit
import AVKit
import KSPlayer

final class ATXKSPlayerHostController: UIViewController {
    var onBack: (() -> Void)?
    private let mediaURL: URL
    private let mediaTitle: String

    private let playerView = IOSVideoPlayerView()
    private let overlay = UIView()
    private let atxTitleLabel = UILabel()
    private let atxBackButton = UIButton(type: .system)
    private let atxPlayButton = UIButton(type: .system)
    private let atxBack10Button = UIButton(type: .system)
    private let atxForward10Button = UIButton(type: .system)
    private let atxFullscreenButton = UIButton(type: .system)
    private let atxRoutePicker = AVRoutePickerView(frame: .zero)

    private var isATXFullscreen = false

    init(url: URL, title: String) {
        self.mediaURL = url
        self.mediaTitle = title
        super.init(nibName: nil, bundle: nil)
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

        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Keep KSPlayer as the decoder/render surface. Hide only its chrome.
        playerView.toolBar.isHidden = true

        buildOverlay()

        let resource = KSPlayerResource(url: mediaURL, name: "")
        playerView.set(resource: resource)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerView.toolBar.isHidden = true
        view.bringSubviewToFront(overlay)
    }

    private func buildOverlay() {
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        view.addSubview(overlay)

        atxTitleLabel.text = mediaTitle
        atxTitleLabel.textColor = .white
        atxTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        atxTitleLabel.textAlignment = .center
        atxTitleLabel.numberOfLines = 1
        atxTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(atxTitleLabel)

        setupButton(atxBackButton, symbol: "chevron.left", selector: #selector(closePlayer))
        setupButton(atxBack10Button, symbol: "gobackward.10", selector: #selector(seekBack))
        setupButton(atxPlayButton, symbol: "playpause.fill", selector: #selector(togglePlayback))
        setupButton(atxForward10Button, symbol: "goforward.10", selector: #selector(seekForward))
        setupButton(atxFullscreenButton, symbol: "arrow.up.left.and.arrow.down.right", selector: #selector(toggleFullscreen))

        atxRoutePicker.prioritizesVideoDevices = true
        atxRoutePicker.tintColor = .white
        atxRoutePicker.activeTintColor = .white
        atxRoutePicker.translatesAutoresizingMaskIntoConstraints = false

        let bottom = UIStackView(arrangedSubviews: [
            atxBack10Button,
            atxPlayButton,
            atxForward10Button,
            atxRoutePicker,
            atxFullscreenButton
        ])
        bottom.axis = .horizontal
        bottom.alignment = .center
        bottom.distribution = .equalSpacing
        bottom.spacing = 20
        bottom.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(bottom)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            atxBackButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            atxBackButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            atxTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: atxBackButton.trailingAnchor, constant: 8),
            atxTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -52),
            atxTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            atxTitleLabel.centerYAnchor.constraint(equalTo: atxBackButton.centerYAnchor),

            bottom.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottom.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            bottom.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.88),

            atxRoutePicker.widthAnchor.constraint(equalToConstant: 34),
            atxRoutePicker.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func setupButton(_ button: UIButton, symbol: String, selector: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    @objc private func closePlayer() {
        if isATXFullscreen {
            setFullscreen(false)
        } else {
            onBack?()
        }
    }

    @objc private func togglePlayback() {
        let player = playerView.playerLayer.player
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    @objc private func seekBack() {
        let player = playerView.playerLayer.player
        let target = max(0, player.currentPlaybackTime - 10)
        player.seek(time: target) { _ in }
    }

    @objc private func seekForward() {
        let player = playerView.playerLayer.player
        let target = player.currentPlaybackTime + 10
        player.seek(time: target) { _ in }
    }

    @objc private func toggleFullscreen() {
        setFullscreen(!isATXFullscreen)
    }

    private func setFullscreen(_ fullscreen: Bool) {
        isATXFullscreen = fullscreen
        let mask: UIInterfaceOrientationMask = fullscreen ? .landscape : .portrait

        if #available(iOS 16.0, *), let scene = view.window?.windowScene {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            scene.requestGeometryUpdate(preferences) { _ in }
            setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(
                fullscreen ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue,
                forKey: "orientation"
            )
        }

        let symbol = fullscreen
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        atxFullscreenButton.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        isATXFullscreen ? .landscape : .portrait
    }

    deinit {
        playerView.playerLayer.player.pause()
    }
}

struct KSPlayerFallbackView: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let onBack: () -> Void

    func makeUIViewController(context: Context) -> ATXKSPlayerHostController {
        let controller = ATXKSPlayerHostController(url: url, title: title)
        controller.onBack = onBack
        return controller
    }

    func updateUIViewController(_ uiViewController: ATXKSPlayerHostController, context: Context) {
        uiViewController.onBack = onBack
    }
}
