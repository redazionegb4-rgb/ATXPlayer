ATX Player 5.1 - Build 204

BASE
- Rebuilt from the original working Build 164 supplied by the user.
- Not based on the broken VLC/MPV experimental builds.

PLAYER
- KSPlayer is the only active player UI.
- FFmpeg-backed KSMEPlayer configured as the secondary engine.
- Uses KSPlayer's IOSVideoPlayerView and its own controls/fullscreen lifecycle.
- No custom second player/control layer is overlaid.
- ATX navigation/tab bars are hidden while playback is open.

FORMATS
KSPlayer/KSMEPlayer is intended for broad FFmpeg-backed playback including
HEVC/H.265 and MKV, while retaining KSPlayer's own UI and fullscreen handling.

XCODE CLOUD
- ci_post_clone.sh explicitly resolves Swift packages before archive.
- KSPlayer pulls FFmpegKit 6.1.4 according to its current Package.swift.
- No VLCKit dependency exists in this build.

VERSION
5.1 (204)

IMPORTANT LICENSING
The public KSPlayer package is GPL. For a proprietary App Store release,
obtain/use the appropriate LGPL/commercial KSPlayer license from its author.
