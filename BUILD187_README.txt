ATX Player 5.1 — Build 187

Restores the full playback control layer lost when all formats were moved to KSPlayer:
- Play/Pause
- 10 seconds back
- 10 seconds forward
- Picture in Picture control
- AirPlay route control
- tap video to show/hide controls

Preserved from Build 186:
- KSPlayer/KSMEPlayer/FFmpeg remains the single playback engine
- RebornTabBar (Home/Diretta/Film/Serie/Download) is not rendered while PlayerScreen is open
- duplicate SwiftUI back chevron remains hidden
- KSPlayer back action closes PlayerScreen

No VLCKit and no dependency change.
