ATX Player 5.1 — Build 181

Rebuilt from the stable Build 176, NOT from Builds 177-180.

Player architecture:
- Live/HLS/native-compatible VOD: existing AVPlayer path.
- MKV/AVI/FLV/WebM: KSPlayer with FFmpeg (KSMEPlayer).
- If AVPlayer rejects another non-live VOD, switch to KSPlayer/FFmpeg using the ORIGINAL URL.
- Removed the old fake .mkv/.avi -> .mp4 URL rewrite.
- Absolutely no VLCKit dependency or runtime linkage.

Swift Package:
https://github.com/kingslay/KSPlayer.git (main)
Product: KSPlayer
KSPlayer itself declares FFmpegKit >= 6.1.4.

NOTE: KSPlayer's public version is GPL. For an App Store closed-source release,
obtain the appropriate LGPL/commercial license from the KSPlayer author.
