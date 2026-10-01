import SwiftUI
import UIKit
import QuartzCore
import Libmpv

// ATX 5.1 / Build 201
// Single playback engine: official MPVKit 1.0.0 (libmpv + FFmpeg).
// No AVPlayer/KSPlayer/VLC fallback is mixed into this screen.

private final class ATXMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if newValue.width > 1, newValue.height > 1 {
                super.drawableSize = newValue
            }
        }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            if Thread.isMainThread {
                super.wantsExtendedDynamicRangeContent = newValue
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.wantsExtendedDynamicRangeContent = newValue
                }
            }
        }
    }
}

@MainActor
private final class ATXMPVController: UIViewController {
    let mediaURL: URL
    let mediaTitle: String
    let isLive: Bool
    var onClose: (() -> Void)?

    private let metalLayer = ATXMetalLayer()
    private var mpv: OpaquePointer?
    private let mpvQueue = DispatchQueue(label: "com.dmb.atxplayer.mpv", qos: .userInitiated)

    private let overlay = UIView()
    private let topBar = UIStackView()
    private let bottomBar = UIStackView()
    private let titleLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let currentLabel = UILabel()
    private let durationLabel = UILabel()
    private let slider = UISlider()
    private let spinner = UIActivityIndicatorView(style: .large)

    private var timer: Timer?
    private var controlsVisible = true
    private var isSeeking = false
    private var isFullscreen = false

    init(url: URL, title: String, isLive: Bool) {
        self.mediaURL = url
        self.mediaTitle = title
        self.isLive = isLive
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupMetalLayer()
        setupControls()
        setupMPV()
        startTimer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metalLayer.frame = view.bounds
        metalLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
    }

    deinit {
        timer?.invalidate()
        if let mpv {
            mpv_set_wakeup_callback(mpv, nil, nil)
            mpv_terminate_destroy(mpv)
        }
    }

    private func setupMetalLayer() {
        metalLayer.frame = view.bounds
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(metalLayer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tap)
    }

    private func setupMPV() {
        guard let handle = mpv_create() else {
            showError("Impossibile inizializzare il player.")
            return
        }
        mpv = handle

        setOption("vo", "gpu-next")
        setOption("gpu-api", "vulkan")
        setOption("gpu-context", "moltenvk")
        setOption("hwdec", "videotoolbox")
        setOption("video-rotate", "no")
        setOption("subs-match-os-language", "yes")
        setOption("subs-fallback", "yes")
        setOption("keep-open", "yes")
        setOption("network-timeout", "15")

        // MPVKit's iOS Metal demo passes the CAMetalLayer as wid.
        var layerObject: AnyObject = metalLayer
        withUnsafeMutablePointer(to: &layerObject) { pointer in
            _ = mpv_set_option(handle, "wid", MPV_FORMAT_INT64, pointer)
        }

        let result = mpv_initialize(handle)
        guard result >= 0 else {
            showError("Errore inizializzazione video: \(errorString(result))")
            return
        }

        mpv_set_wakeup_callback(handle, { ctx in
            guard let ctx else { return }
            let controller = Unmanaged<ATXMPVController>.fromOpaque(ctx).takeUnretainedValue()
            controller.readEvents()
        }, Unmanaged.passUnretained(self).toOpaque())

        spinner.startAnimating()
        command(["loadfile", mediaURL.absoluteString, "replace"])
    }

    private func setOption(_ name: String, _ value: String) {
        guard let mpv else { return }
        _ = mpv_set_option_string(mpv, name, value)
    }

    private func command(_ values: [String]) {
        guard let mpv else { return }
        mpvQueue.async {
            var storage = values.map { strdup($0) }
            defer { storage.forEach { free($0) } }
            var args: [UnsafePointer<CChar>?] = storage.map { UnsafePointer($0) }
            args.append(nil)
            args.withUnsafeMutableBufferPointer { buffer in
                _ = mpv_command(mpv, buffer.baseAddress)
            }
        }
    }

    private func readEvents() {
        guard let mpv else { return }
        mpvQueue.async { [weak self] in
            guard let self else { return }
            while true {
                guard let event = mpv_wait_event(mpv, 0) else { break }
                if event.pointee.event_id == MPV_EVENT_NONE { break }

                switch event.pointee.event_id {
                case MPV_EVENT_FILE_LOADED:
                    Task { @MainActor in
                        self.spinner.stopAnimating()
                        self.refreshUI()
                    }
                case MPV_EVENT_END_FILE:
                    let data = event.pointee.data
                    if let data {
                        let end = data.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                        if end.reason == MPV_END_FILE_REASON_ERROR {
                            Task { @MainActor in
                                self.spinner.stopAnimating()
                                self.showError("Riproduzione non riuscita: \(self.errorString(end.error))")
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    private func getDouble(_ name: String) -> Double {
        guard let mpv else { return 0 }
        var value = Double()
        guard mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &value) >= 0 else { return 0 }
        return value
    }

    private func getFlag(_ name: String) -> Bool {
        guard let mpv else { return false }
        var value: Int32 = 0
        guard mpv_get_property(mpv, name, MPV_FORMAT_FLAG, &value) >= 0 else { return false }
        return value != 0
    }

    private func setPause(_ paused: Bool) {
        guard let mpv else { return }
        var value: Int32 = paused ? 1 : 0
        _ = mpv_set_property(mpv, "pause", MPV_FORMAT_FLAG, &value)
    }

    private func errorString(_ code: Int32) -> String {
        guard let c = mpv_error_string(code) else { return "errore \(code)" }
        return String(cString: c)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshUI() }
        }
    }

    private func refreshUI() {
        guard mpv != nil else { return }
        let paused = getFlag("pause")
        playButton.setImage(UIImage(systemName: paused ? "play.fill" : "pause.fill"), for: .normal)

        guard !isLive else {
            currentLabel.text = "LIVE"
            durationLabel.text = ""
            slider.isHidden = true
            return
        }

        let pos = max(0, getDouble("time-pos"))
        let dur = max(0, getDouble("duration"))
        currentLabel.text = format(pos)
        durationLabel.text = format(dur)
        if !isSeeking, dur > 0 {
            slider.value = Float(min(1, pos / dur))
        }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func setupControls() {
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        view.addSubview(overlay)

        let close = iconButton("chevron.left", #selector(closeTapped))
        let fullscreen = iconButton("arrow.up.left.and.arrow.down.right", #selector(fullscreenTapped))

        titleLabel.text = mediaTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        topBar.axis = .horizontal
        topBar.alignment = .center
        topBar.spacing = 10
        topBar.addArrangedSubview(close)
        topBar.addArrangedSubview(titleLabel)
        topBar.addArrangedSubview(fullscreen)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(topBar)

        let back10 = iconButton("gobackward.10", #selector(back10Tapped))
        playButton.tintColor = .white
        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.widthAnchor.constraint(equalToConstant: 58).isActive = true
        playButton.heightAnchor.constraint(equalToConstant: 58).isActive = true
        let forward10 = iconButton("goforward.10", #selector(forward10Tapped))

        currentLabel.textColor = .white
        currentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        durationLabel.textColor = .white
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        slider.addTarget(self, action: #selector(sliderDown), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let timeline = UIStackView(arrangedSubviews: [currentLabel, slider, durationLabel])
        timeline.axis = .horizontal
        timeline.alignment = .center
        timeline.spacing = 10

        let transport = UIStackView(arrangedSubviews: [back10, playButton, forward10])
        transport.axis = .horizontal
        transport.alignment = .center
        transport.distribution = .equalCentering
        transport.spacing = 34

        bottomBar.axis = .vertical
        bottomBar.alignment = .fill
        bottomBar.spacing = 12
        bottomBar.addArrangedSubview(timeline)
        bottomBar.addArrangedSubview(transport)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(bottomBar)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        overlay.addSubview(spinner)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            bottomBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        if isLive {
            back10.isHidden = true
            forward10.isHidden = true
            slider.isHidden = true
        }
    }

    private func iconButton(_ symbol: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .semibold)), for: .normal)
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func toggleControls() {
        controlsVisible.toggle()
        UIView.animate(withDuration: 0.2) {
            self.topBar.alpha = self.controlsVisible ? 1 : 0
            self.bottomBar.alpha = self.controlsVisible ? 1 : 0
        }
    }

    @objc private func closeTapped() {
        if isFullscreen {
            setFullscreen(false)
        } else {
            onClose?()
        }
    }

    @objc private func playTapped() {
        setPause(!getFlag("pause"))
        refreshUI()
    }

    @objc private func back10Tapped() { command(["seek", "-10", "relative"]) }
    @objc private func forward10Tapped() { command(["seek", "10", "relative"]) }

    @objc private func sliderDown() { isSeeking = true }
    @objc private func sliderChanged() {}
    @objc private func sliderUp() {
        let duration = getDouble("duration")
        if duration > 0 {
            command(["seek", String(Double(slider.value) * duration), "absolute"])
        }
        isSeeking = false
    }

    @objc private func fullscreenTapped() {
        setFullscreen(!isFullscreen)
    }

    private func setFullscreen(_ enabled: Bool) {
        isFullscreen = enabled
        if #available(iOS 16.0, *), let scene = view.window?.windowScene {
            let mask: UIInterfaceOrientationMask = enabled ? .landscape : .portrait
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        isFullscreen ? .landscape : .portrait
    }

    override var prefersHomeIndicatorAutoHidden: Bool { isFullscreen }

    private func showError(_ message: String) {
        spinner.stopAnimating()
        let alert = UIAlertController(title: "Riproduzione non disponibile", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Chiudi", style: .default) { [weak self] _ in self?.onClose?() })
        present(alert, animated: true)
    }
}

private struct ATXMPVContainer: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let isLive: Bool
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let c = ATXMPVController(url: url, title: title, isLive: isLive)
        c.onClose = onClose
        return c
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
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
                ATXMPVContainer(url: selectedURL, title: title, isLive: isLive) {
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
