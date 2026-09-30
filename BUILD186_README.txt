ATX Player 5.1 — Build 186

Fix based on the two real-device screenshots:

1. CUSTOM BOTTOM MENU REALLY HIDDEN
The bar shown in the screenshots is RebornTabBar, not Apple's native tab bar.
MainTabView now observes PlayerPresentationState and does not render RebornTabBar
while PlayerScreen is open.

2. PLAYER UI / DUPLICATE BACK
KSPlayer/KSMEPlayer remains the playback engine for Live, Film and Series.
The native NavigationStack back chevron is hidden.
KSPlayer's own back button remains and is wired to SwiftUI dismiss().
The resource is loaded with the content title so KSPlayer gets the proper media metadata/control UI.

No dependency changes. Package.resolved unchanged. No VLCKit.
