import SwiftUI
import UIKit
import AVKit
import MediaPlayer
import KSPlayer

private final class ATXKSPlayerView: IOSVideoPlayerView {
    var atxBack: (() -> Void)?
    private var isATXFullscreen = false

    private let chrome = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let back10Button = UIButton(type: .system)
    private let forward10Button = UIButton(type: .system)
    private let fullscreenButton = UIButton(type: .system)
    private let routePicker = AVRoutePickerView(frame: .zero)

    override init() {
        super.init()
        buildATXControls()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildATXControls()
    }

    private func buildATXControls() {
        backgroundColor = .black

        // We use KSPlayer only as playback/rendering engine.
        // Its toolbar is hidden because its internal landscape/fullscreen transition
        // is the path that was freezing the stream.
        toolBar.isHidden = true

        chrome.backgroundColor = .clear
        chrome.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chrome)

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(titleLabel)

        configure(backButton, systemName: "chevron.left", action: #selector(goBack))
        configure(back10Button, systemName: "gobackward.10", action: #selector(seekBack))
        configure(playButton, systemName: "playpause.fill", action: #selector(togglePlayback))
        configure(forward10Button, systemName: "goforward.10", action: #selector(seekForward))
        configure(fullscreenButton, systemName: "arrow.up.left.and.arrow.down.right", action: #selector(toggleFullscreen))

        routePicker.prioritizesVideoDevices = true
        routePicker.tintColor = .white
        routePicker.activeTintColor = .white
        routePicker.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(routePicker)

        let controls = UIStackView(arrangedSubviews: [
            back10Button, playButton, forward10Button, routePicker, fullscreenButton
        ])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.distribution = .equalSpacing
        controls.spacing = 24
        controls.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(controls)

        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: trailingAnchor),
            chrome.topAnchor.constraint(equalTo: topAnchor),
            chrome.bottomAnchor.constraint(equalTo: bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 14),
            backButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -58),
            titleLabel.centerXAnchor.constraint(equalTo: chrome.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            controls.centerXAnchor.constraint(equalTo: chrome.centerXAnchor),
            controls.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controls.widthAnchor.constraint(lessThanOrEqualTo: chrome.widthAnchor, multiplier: 0.86),

            routePicker.widthAnchor.constraint(equalToConstant: 30),
            routePicker.heightAnchor.constraint(equalToConstant: 30)
        ])

        bringSubviewToFront(chrome)
    }

    private func configure(_ button: UIButton, systemName: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        chrome.addSubview(button)
    }

    func setATXTitle(_ title: String) {
        titleLabel.text = title
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        toolBar.isHidden = true
        bringSubviewToFront(chrome)
    }

    @objc private func goBack() {
        if isATXFullscreen {
            setATXFullscreen(false)
        } else {
            atxBack?()
        }
    }

    @objc private func togglePlayback() {
        guard let player = playerLayer?.player else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    @objc private func seekBack() {
        guard let player = playerLayer?.player else { return }
        let target = max(0, player.currentPlaybackTime - 10)
        player.seek(time: target) { _ in }
    }

    @objc private func seekForward() {
        guard let player = playerLayer?.player else { return }
        let target = player.currentPlaybackTime + 10
        player.seek(time: target) { _ in }
    }

    @objc private func toggleFullscreen() {
        setATXFullscreen(!isATXFullscreen)
    }

    private func setATXFullscreen(_ fullscreen: Bool) {
        isATXFullscreen = fullscreen

        // Keep the same KSPlayer view/layer/player alive.
        // Only the window orientation changes; the stream is never detached/recreated.
        let mask: UIInterfaceOrientationMask = fullscreen ? .landscape : .portrait

        if #available(iOS 16.0, *), let scene = window?.windowScene {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            scene.requestGeometryUpdate(preferences) { _ in }
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(
                fullscreen ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue,
                forKey: "orientation"
            )
        }

        let icon = fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        fullscreenButton.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
    }
}

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

    func makeUIView(context: Context) -> ATXKSPlayerView {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true

        let view = ATXKSPlayerView()
        view.atxBack = onBack
        view.setATXTitle(title)

        // Empty KS resource name prevents KSPlayer's title from being drawn over the clock.
        let resource = KSPlayerResource(url: url, name: "")
        context.coordinator.loadedURL = url
        view.set(resource: resource)
        return view
    }

    func updateUIView(_ uiView: ATXKSPlayerView, context: Context) {
        uiView.atxBack = onBack
        uiView.setATXTitle(title)

        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let resource = KSPlayerResource(url: url, name: "")
        uiView.set(resource: resource)
    }

    static func dismantleUIView(_ uiView: ATXKSPlayerView, coordinator: Coordinator) {
        uiView.playerLayer?.player?.pause()
    }
}
