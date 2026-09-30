ATX Player 5.1 — Build 182

Xcode Cloud dependency-resolution fix.

KSPlayer is no longer tracking the moving 'main' branch.
Pinned revision:
76aae3dca1f54bd36bb036a4fb261b0c9dc30d91

Package.resolved is committed with:
- KSPlayer @ 76aae3dca1f54bd36bb036a4fb261b0c9dc30d91
- FFmpegKit 6.1.4
- FFmpegKit revision c32be9bfb628042737ad3ef622e930c5c7b15954

This is specifically for the Xcode Cloud workflow where automatic package
dependency resolution is disabled.

Player architecture from Build 181 is unchanged:
- AVPlayer for native/HLS/live-compatible playback.
- KSPlayer/KSMEPlayer + FFmpeg fallback for MKV/AVI/FLV/WebM and unsupported VOD.
- No VLCKit.
