ATX Player 5.1 Build 178

Fix for:
The file 'VLCKit-product' couldn't be opened because there is no such file.

Build 177 manually copied the Swift Package product in an Embed Frameworks phase.
That is removed in Build 178. VLCKit remains a normal Swift Package target dependency
and is linked in PBXFrameworksBuildPhase.

- VLCKit exact 4.0.0-a22
- Package.resolved aligned
- MKV/AVI fallback retained
- AVPlayer retained for native-compatible streams
