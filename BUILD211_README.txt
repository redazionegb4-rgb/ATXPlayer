ATX Player 5.1 (211)
FIX 1 MKV:
- MunimFFmpeg static remains.
- MKV is remuxed progressively to 2-second fMP4/HLS fragments.
- A local 127.0.0.1 HTTP server feeds the growing HLS playlist to the ORIGINAL AVPlayer.
- Playback can start after the first fragment instead of waiting for the full VOD.
- Original AVPlayer/AVKit remains visible, preserving its PiP/fullscreen/AirPlay path.

FIX 2 GLOBAL SEARCH:
- Live channels are searched with session.allLive and are now shown FIRST in global results,
  before film/series, so they no longer appear buried below up to 80 poster results.

FIX 3 COPY CODE:
- The activation screen still displays ATX-XXXX-XXXX-XXXX.
- COPIA CODICE now copies only XXXX-XXXX-XXXX (without the ATX- prefix).

GitHub:
- Device-only ios-arm64 Munim static slice retained.
- No >100 MB simulator binary.
