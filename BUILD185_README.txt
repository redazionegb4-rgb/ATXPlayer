ATX Player 5.1 — Build 185

Player presentation/UI correction:
- keeps KSPlayer/KSMEPlayer (FFmpeg) as the single playback engine;
- uses IOSVideoPlayerView's own player controls instead of duplicating navigation;
- removes the redundant custom SwiftUI back overlay where present;
- adds a shared PlayerPresentationState so the application shell can suppress its
  bottom navigation while playback is presented;
- native tab bar hiding remains enabled as an additional safeguard;
- player content mode is aspect-fit to avoid stretched/misaligned video.

No dependency changes. Package.resolved unchanged. No VLCKit.
