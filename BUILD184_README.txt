ATX Player 5.1 — Build 184

1) Single player engine
KSPlayer/KSMEPlayer (FFmpeg) is now used for ALL playback:
- Live
- Film
- Series episodes
No per-format AVPlayer routing is used when opening content.

2) Bottom navigation
The app TabView bottom bar is hidden while PlayerScreen is open and returns
when leaving playback.

Based directly on Build 183. Package.resolved unchanged. No VLCKit.
