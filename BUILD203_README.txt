ATX Player 5.1 (203)

Clean rebuild from user-provided Build 164.

PLAYER ENGINE
- Replaced the active AVPlayer PlayerScreen with VLCKit/libVLC.
- The original AVPlayer PlayerScreen is preserved as LegacyAVPlayerScreen.
- Uses VideoLAN VLCKit 4 binary package (2026-08-31 build).
- One VLCMediaPlayer instance owns decoding/playback.
- ATX UI controls do not call into a second player.

CONTROLS
- Back
- Play/Pause
- -10/+10 seconds for VOD
- VOD timeline
- Live mode
- Fullscreen by orientation change while keeping the same VLCMediaPlayer instance
- ATX tab/navigation bars hidden during playback

DEPENDENCY PACKAGING
- No remote Swift source package dependency.
- A LOCAL Swift package lives in Vendor/VLCKitLocal.
- That local package points directly to VideoLAN's official binary artifact.
- Therefore this repository does NOT need Package.resolved for VLCKit.
- No ci_post_clone.sh is included.

Version 5.1
Build 203
