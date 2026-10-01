ATX Player 5.1 (207)

BASE
- Exact user-provided Build 164 original.
- Original AVPlayer / AVPlayerViewController retained.
- No KSPlayer, VLCKit, MPVKit, FFmpegKit or other third-party player.
- No Swift Package dependencies.
- No Package.resolved.
- No ci_post_clone.sh.

MKV VOD FIX
- For non-live VOD/episode URLs ending in .mkv, ATX requests the same Xtream-style
  stream id using .mp4 instead.
- This is a server-container compatibility request, not a second player.
- The visible player remains the original native AVPlayerViewController.
- Native PiP, fullscreen and AirPlay behavior from Build 164 remains unchanged.
- Auto-next episodes use the same MKV -> MP4 compatibility rule.

IMPORTANT
This fix depends on the Xtream-compatible provider accepting the same VOD/episode
stream id with an .mp4 container. It cannot make AVPlayer decode Matroska bytes
when the server only serves MKV.
