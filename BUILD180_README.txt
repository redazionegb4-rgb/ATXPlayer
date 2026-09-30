ATX Player 5.1 Build 180
Fix: Multiple commands produce ATXPlayer.app/Frameworks/VLCKit.framework.

The custom runtime phase no longer declares VLCKit.framework as an Xcode output,
so it does not collide with Swift Package Manager. The phase runs last and retains
the final bundle copy/sign repair required by the Build 178 DYLD crash.
