ATX Player 5.1 — Build 189

FIX PLAYER:
1. Removed the second SwiftUI playback-control overlay introduced in Build 188.
   KSPlayer is now the ONLY player/control surface, preventing duplicate play/pause,
   seek and AirPlay controls.

2. Fullscreen stability:
   PlayerScreen already occupies the full application surface and ignores safe areas.
   The KSPlayer internal fullscreen button/path is suppressed to avoid a second UIKit
   fullscreen/reparent operation that could interrupt audio, detach playback, or trap
   navigation. Playback remains in one continuous player instance.

3. Back/navigation:
   KSPlayer remains the single visible player UI. Existing backBlock still dismisses
   PlayerScreen, and the app tab bar stays hidden while playback is presented.

4. No VLCKit. No second player instance. KSPlayer/KSMEPlayer/FFmpeg remains the playback engine.
