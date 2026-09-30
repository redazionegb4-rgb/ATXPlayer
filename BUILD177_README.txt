ATX Player 5.1 Build 177 — codec fix
Base: user-provided Build 176 CLEAN/STABLE.

- MKV/AVI VOD: original URL is opened by VLCKit; no extension rewriting.
- AVPlayer remains unchanged for HLS/MP4/live streams.
- If AVPlayer fails on another VOD, fallback uses the original URL in VLC.
- VLCKit is not instantiated until an unsupported VOD is opened.
- VLCKit 4.0.0-a22 is pinned and Package.resolved matches Xcode Cloud.
- Explicit Embed Frameworks phase added with CodeSignOnCopy to avoid launch-time dyld/framework crash.
- Existing app/login/API/live behavior is otherwise left on the Build 176 base.
