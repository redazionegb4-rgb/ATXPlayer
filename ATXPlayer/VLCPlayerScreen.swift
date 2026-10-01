import SwiftUI
import UIKit
import VLCKit

final class ATXVLCViewController: UIViewController, VLCMediaPlayerDelegate {
    let mediaURL: URL
    let mediaTitle: String
    let isLive: Bool
    var onClose: (() -> Void)?

    private let videoSurface = UIView()
    private let player = VLCMediaPlayer()
    private let titleLabel = UILabel()
    private let controls = UIView()
    private let playButton = UIButton(type: .system)
    private let slider = UISlider()
    private let currentLabel = UILabel()
    private let durationLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var timer: Timer?
    private var userSeeking = false
    private var fullscreen = false

    init(url: URL, title: String, isLive: Bool) {
        self.mediaURL = url
        self.mediaTitle = title
        self.isLive = isLive
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSurface()
        setupControls()

        player.delegate = self
        player.drawable = videoSurface

        let media = VLCMedia(url: mediaURL)
        player.media = media
        spinner.startAnimating()
        player.play()

        timer = Timer.scheduledTimer(timeInterval: 0.5,
                                     target: self,
                                     selector: #selector(refreshUI),
                                     userInfo: nil,
                                     repeats: true)
    }

    deinit {
        timer?.invalidate()
        player.stop()
        player.drawable = nil
    }

    private func setupSurface() {
        videoSurface.translatesAutoresizingMaskIntoConstraints = false
        videoSurface.backgroundColor = .black
        view.addSubview(videoSurface)
        NSLayoutConstraint.activate([
            videoSurface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoSurface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoSurface.topAnchor.constraint(equalTo: view.topAnchor),
            videoSurface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        videoSurface.addGestureRecognizer(tap)
    }

    private func setupControls() {
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.backgroundColor = .clear
        view.addSubview(controls)

        let back = makeButton("chevron.left", #selector(backTapped))
        let fullscreenButton = makeButton("arrow.up.left.and.arrow.down.right", #selector(fullscreenTapped))

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = mediaTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        let top = UIStackView(arrangedSubviews: [back, titleLabel, fullscreenButton])
        top.axis = .horizontal
        top.alignment = .center
        top.spacing = 10
        top.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(top)

        let minus10 = makeButton("gobackward.10", #selector(back10Tapped))
        playButton.tintColor = .white
        playButton.setImage(UIImage(systemName: "pause.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)),
                            for: .normal)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        let plus10 = makeButton("goforward.10", #selector(forward10Tapped))

        let transport = UIStackView(arrangedSubviews: [minus10, playButton, plus10])
        transport.axis = .horizontal
        transport.alignment = .center
        transport.distribution = .equalCentering
        transport.spacing = 36

        currentLabel.textColor = .white
        currentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        durationLabel.textColor = .white
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        slider.addTarget(self, action: #selector(sliderDown), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let timeline = UIStackView(arrangedSubviews: [currentLabel, slider, durationLabel])
        timeline.axis = .horizontal
        timeline.alignment = .center
        timeline.spacing = 10

        let bottom = UIStackView(arrangedSubviews: [timeline, transport])
        bottom.axis = .vertical
        bottom.alignment = .fill
        bottom.spacing = 12
        bottom.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(bottom)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        controls.addSubview(spinner)

        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: view.topAnchor),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            top.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            top.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            bottom.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            bottom.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            bottom.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        if isLive {
            minus10.isHidden = true
            plus10.isHidden = true
            slider.isHidden = true
            currentLabel.text = "LIVE"
            durationLabel.text = ""
        }
    }

    private func makeButton(_ symbol: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.tintColor = .white
        b.setImage(UIImage(systemName: symbol,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .semibold)),
                   for: .normal)
        b.widthAnchor.constraint(equalToConstant: 48).isActive = true
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc private func refreshUI() {
        spinner.stopAnimating()

        let playing = player.isPlaying
        playButton.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)),
                            for: .normal)

        guard !isLive else { return }

        let total = max(0, Int64(player.media?.length.intValue ?? 0))
        let current = max(0, Int64(player.time.intValue))
        currentLabel.text = format(milliseconds: current)
        durationLabel.text = format(milliseconds: total)

        if !userSeeking, total > 0 {
            slider.value = Float(Double(current) / Double(total))
        }
    }

    private func format(milliseconds: Int64) -> String {
        let seconds = max(0, milliseconds / 1000)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%lld:%02lld:%02lld", h, m, s)
                     : String(format: "%02lld:%02lld", m, s)
    }

    @objc private func toggleControls() {
        let hidden = controls.alpha > 0.5
        UIView.animate(withDuration: 0.2) {
            self.controls.alpha = hidden ? 0 : 1
        }
    }

    @objc private func backTapped() {
        if fullscreen {
            setFullscreen(false)
        } else {
            onClose?()
        }
    }

    @objc private func playTapped() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
        refreshUI()
    }

    @objc private func back10Tapped() {
        guard !isLive else { return }
        player.time = VLCTime(int: max(0, player.time.intValue - 10_000))
    }

    @objc private func forward10Tapped() {
        guard !isLive else { return }
        let duration = player.media?.length.intValue ?? 0
        let target = player.time.intValue + 10_000
        player.time = VLCTime(int: duration > 0 ? min(target, duration) : target)
    }

    @objc private func sliderDown() {
        userSeeking = true
    }

    @objc private func sliderUp() {
        let duration = player.media?.length.intValue ?? 0
        if duration > 0 {
            player.time = VLCTime(int: Int32(Float(duration) * slider.value))
        }
        userSeeking = false
    }

    @objc private func fullscreenTapped() {
        setFullscreen(!fullscreen)
    }

    private func setFullscreen(_ enabled: Bool) {
        fullscreen = enabled
        if #available(iOS 16.0, *), let scene = view.window?.windowScene {
            let mask: UIInterfaceOrientationMask = enabled ? .landscape : .portrait
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            scene.requestGeometryUpdate(preferences)
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        fullscreen ? .landscape : .portrait
    }

    override var prefersHomeIndicatorAutoHidden: Bool { fullscreen }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshUI()
        }
    }
}

struct ATXVLCContainer: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let isLive: Bool
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> ATXVLCViewController {
        let controller = ATXVLCViewController(url: url, title: title, isLive: isLive)
        controller.onClose = onClose
        return controller
    }

    func updateUIViewController(_ uiViewController: ATXVLCViewController, context: Context) {
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

    private var playbackURL: URL? {
        if !episodeQueue.isEmpty, episodeQueue.indices.contains(startIndex) {
            return episodeQueue[startIndex].url
        }
        return url
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let playbackURL {
                ATXVLCContainer(url: playbackURL, title: title, isLive: isLive) {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "play.slash")
                    Text("Riproduzione non disponibile")
                }
                .foregroundStyle(.white)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black)
    }
}
