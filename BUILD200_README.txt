ATX Player 5.1 - Build 200

Xcode Cloud package-resolution fix:
- MPVKit/libmpv retained.
- Added executable ci_scripts/ci_post_clone.sh.
- It removes stale Package.resolved and resolves SwiftPM dependencies before Archive.
- No playback/UI changes from Build 199.
