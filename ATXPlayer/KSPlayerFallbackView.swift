import SwiftUI
import UIKit
import KSPlayer

final class ATXKSPlayerController: UIViewController {
    private let mediaURL: URL
    private let mediaTitle: String
    var onBack: (() -> Void)?

    private let videoView = IOSVideoPlayerView()
    private let closeButton = UIButton(type: .system)
    private let titleView = UILabel()

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

        // One decoder path only. Do not manipulate playerLayer/player directly.
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

        configureHeader()

        // Let KSPlayer create, own and control its player lifecycle.
        let resource = KSPlayerResource(url: mediaURL, name: mediaTitle)
        videoView.set(resource: resource)
    }

    private func configureHeader() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .white
        closeButton.setImage(
            UIImage(systemName: "chevron.left",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)),
            for: .normal
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.text = mediaTitle
        titleView.textColor = .white
        titleView.font = .systemFont(ofSize: 17, weight: .semibold)
        titleView.textAlignment = .center
        titleView.lineBreakMode = .byTruncatingTail

        view.addSubview(closeButton)
        view.addSubview(titleView)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            titleView.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleView.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            titleView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -56)
        ])
    }

    @objc private func closeTapped() {
        onBack?()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(closeButton)
        view.bringSubviewToFront(titleView)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
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
