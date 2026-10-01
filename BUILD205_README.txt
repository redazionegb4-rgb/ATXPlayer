ATX Player 5.1 (205)

BASE: exact user-provided Build 164 clean project.

NEW LOCAL COMPATIBILITY PIPELINE
- AVPlayer/AVPlayerViewController remains the visible player.
- Native Apple fullscreen, Picture in Picture and AirPlay remain enabled.
- If AVPlayer reports the original item as failed, ATX starts FFmpeg ON DEVICE.
- First pass remuxes video without re-encoding and converts audio to AAC.
- Output is a local HLS playlist consumed by the SAME native AVPlayer UI.
- If stream-copy cannot produce HLS, a VideoToolbox H.264 fallback is attempted.

DEPENDENCIES
- FFmpegKit and all FFmpeg XCFrameworks are physically included under Vendor/FFmpegKit.
- Local Swift Package only. No remote SPM dependency.
- No Package.resolved needed.
- No ci_post_clone.sh.
- No VLC / KSPlayer / MPV.

IMPORTANT
This package was structurally validated in the build environment, but an actual iOS Archive/TestFlight run cannot be executed here. Device validation is still required for the specific provider streams.
