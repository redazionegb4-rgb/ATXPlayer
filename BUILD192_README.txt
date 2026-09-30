ATX Player 5.1 - Build 192

This build changes the player architecture instead of patching KSPlayer fullscreen.

- KSPlayer/KSMEPlayer/FFmpeg remains the playback engine for all streams.
- KSPlayer's own toolbar is hidden.
- ATX controls are used: Back, -10 seconds, Play/Pause, +10 seconds, AirPlay, Fullscreen.
- Fullscreen NEVER invokes KSPlayer's internal landscape/fullscreen UI.
- Fullscreen changes only the window orientation, preserving the same player view/layer/stream.
- Exiting fullscreen returns to portrait without recreating playback.
- KSPlayer receives an empty title. ATX draws the title inside the safe area.
- SwiftUI navigation bar is hidden in PlayerScreen to prevent a duplicate title/back control.
- Existing app bottom-tab hiding remains unchanged.
