#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCHEME="SwiftlyCodeEdit"
BUILD_CONFIGURATION="${1:-release}"
BINARY_PATH="$REPO_ROOT/.build/$BUILD_CONFIGURATION/$SCHEME"
ICON_SOURCE="$REPO_ROOT/Resources/$SCHEME.icns"
OUTPUT_DIR="$REPO_ROOT/build"
APP_BUNDLE="$OUTPUT_DIR/$SCHEME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$REPO_ROOT"

echo "Building $BUILD_CONFIGURATION $SCHEME"
swift build --disable-sandbox -c "$BUILD_CONFIGURATION"

if [ ! -f "$BINARY_PATH" ]; then
  echo "Built binary not found at $BINARY_PATH" >&2
  exit 1
fi

if [ ! -f "$ICON_SOURCE" ]; then
  echo "Icon not found at $ICON_SOURCE" >&2
  exit 1
fi

# Start each bundle assembly from a clean slate so a stale prior run cannot
# leave orphaned files behind under the new bundle contents.
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$SCHEME"
cp "$ICON_SOURCE" "$RESOURCES_DIR/$SCHEME.icns"

# SHORT_VERSION comes from the repo-root VERSION file when present, falling
# back to 0.1 so the bundle still assembles before the first tagged release.
SHORT_VERSION="0.1"
if [ -f "$REPO_ROOT/VERSION" ]; then
  SHORT_VERSION="$(cat "$REPO_ROOT/VERSION")"
fi

cat >"$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>$SCHEME</string>
	<key>CFBundleDisplayName</key>
	<string>$SCHEME</string>
	<key>CFBundleIdentifier</key>
	<string>org.vosslab.$SCHEME</string>
	<key>CFBundleExecutable</key>
	<string>$SCHEME</string>
	<key>CFBundleIconFile</key>
	<string>$SCHEME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$SHORT_VERSION</string>
	<key>CFBundleGetInfoString</key>
	<string>A fast native code editor for macOS.</string>
	<key>LSMinimumSystemVersion</key>
	<string>26.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"

echo "Bundle assembled at $APP_BUNDLE"
