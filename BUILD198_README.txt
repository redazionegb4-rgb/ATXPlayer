ATX Player 5.1 - Build 198

STABILITY RESET

This build deliberately returns to the clean Build 191 playback implementation,
before the custom KSPlayer control/fullscreen experiments.

- Single playback engine: KSPlayer KSMEPlayer/FFmpeg.
- Single matching KSPlayer native control surface.
- No ATX custom controls layered on KSPlayer.
- No second player/controller.
- No custom fullscreen reparenting/orientation controller.
- App bottom tab bar remains hidden while PlayerScreen is open.
- Build number: 198.

Reason:
The later custom-control builds mixed KSPlayer's playback object with an external
control/fullscreen layer and introduced crashes when Play was pressed. This build
removes that architecture rather than patching it again.
