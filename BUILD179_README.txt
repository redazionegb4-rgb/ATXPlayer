ATX Player 5.1 Build 179 — VLCKit runtime embed fix

Based directly on the uploaded Build 178.

Device crash diagnosis:
DYLD 1 Library missing
@rpath/VLCKit.framework/VLCKit

Build 179 keeps the working SPM link but adds a build phase that:
1. finds the actual resolved VLCKit.framework in Xcode build products;
2. copies the real framework into ATXPlayer.app/Frameworks;
3. signs the embedded framework with the app build identity.

This avoids the incorrect Build 177 approach that attempted to copy the SPM
pseudo-product 'VLCKit-product'.

MKV/AVI -> VLCKit playback code remains unchanged from Build 178.
AVPlayer remains the normal player for native-compatible streams.
