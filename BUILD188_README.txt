ATX Player 5.1 — Build 188

Fixes all four compiler errors from Build 187:
- Coordinator is NSObject-based, so weak-self observer closures resolve correctly.
- KSPlayer seek calls now include the required completion closure.
- AirPlayRouteButton replaced with a real AVRoutePickerView SwiftUI wrapper.
- No unstable PiP API call is added.

Preserved:
- KSPlayer/KSMEPlayer/FFmpeg single playback engine.
- RebornTabBar hidden while PlayerScreen is open.
- Duplicate back arrow hidden.
- KSPlayer back button dismisses the player.
- Player overlay: -10s, Play/Pause, +10s, AirPlay.
