import SwiftUI
import MPVKit

// Build 199 test:
// the old type name is intentionally retained so MainViews does not need a risky
// navigation rewrite. Internally this is now MPVKit/libmpv, NOT KSPlayer.
struct KSPlayerFallbackView: View {
    let url: URL
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            MPVVideoPlayer(url: url)
                .ignoresSafeArea()

            // Keep navigation outside libmpv. No custom playback/fullscreen commands
            // are wired in this first compatibility build.
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
