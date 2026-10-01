ATX Player 5.1 (202) - CLEAN XCODE CLOUD BUILD

This build is based on Build 201 and is specifically repackaged to remove the
two Xcode Cloud failures shown by the user:

1. NO ci_post_clone.sh exists anywhere in this package.
2. Package.resolved is committed at:
   ATXPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

MPVKit:
- https://github.com/mpvkit/MPVKit.git
- exact version 1.0.0
- revision 288527dffbc6d3e63cce147fc7b520c64a791603

Version:
- MARKETING_VERSION 5.1
- CURRENT_PROJECT_VERSION 202

IMPORTANT:
Replace the repository contents with this package. Do not merge it over a
repository that still contains ci_scripts/ci_post_clone.sh, because Git does
not delete old tracked files merely because they are absent from an uploaded ZIP.
