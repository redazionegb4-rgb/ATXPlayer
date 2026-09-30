ATX Player 5.1 — Build 190

Compile fix after Build 189:
- Removed the 3 stale Notification.Name references left in KSPlayerFallbackView:
  atxKSSeekBack, atxKSTogglePlay, atxKSSeekForward.
- These belonged to the duplicate custom control overlay that Build 189 removed.
- They are NOT reintroduced, so there is still only one player/control UI.
- Preserves the Build 189 single-player/fullscreen stability changes.
