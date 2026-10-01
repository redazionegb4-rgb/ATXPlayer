ATX Player 5.1 - Build 199 - libmpv experiment

PLAYER ENGINE CHANGED
- KSPlayer dependency removed.
- MPVKit/libmpv dependency added through Swift Package Manager.
- MPVKit requires iOS 17+, so deployment target is now iOS 17.
- Film, Series and Live all route to MPVVideoPlayer/libmpv.

FIRST TEST PURPOSE
This build deliberately does NOT add custom play/fullscreen/seek commands yet.
The goal is to establish whether libmpv itself:
1. opens the H.265/MKV episode that failed with AVPlayer,
2. opens normal films/episodes,
3. opens Live streams,
4. remains stable during basic playback.

Once engine stability is confirmed, ATX controls can be built against libmpv's own
command/property API instead of mixing controls from another player framework.

SwiftPM:
https://github.com/karelrooted/MPVKit
Product: MPVKit
Branch: main
