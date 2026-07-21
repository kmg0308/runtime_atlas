#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RuntimeAtlas"
DISPLAY_NAME="Runtime Atlas"
APP_EXECUTABLE="RuntimeAtlas"
CLI_EXECUTABLE="runtime-atlas"
BUNDLE_ID="com.kmg0308.runtimeatlas"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
BUILD_COMMIT="${BUILD_COMMIT:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo dev)}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
PKG_ROOT="$DIST_DIR/pkgroot"
COMPONENT_PLIST="$DIST_DIR/$APP_NAME-component.plist"

xml_escape() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    printf '%s' "$value"
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

cd "$ROOT_DIR"
swift build -c release --product "$APP_EXECUTABLE" -Xswiftc -warnings-as-errors
swift build -c release --product "$CLI_EXECUTABLE" -Xswiftc -warnings-as-errors
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Helpers" "$APP_DIR/Contents/Resources"
install -m 0755 "$BIN_DIR/$APP_EXECUTABLE" "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE"
install -m 0755 "$BIN_DIR/$CLI_EXECUTABLE" "$APP_DIR/Contents/Helpers/$CLI_EXECUTABLE"
swift "$ROOT_DIR/scripts/make_icon.swift" "$APP_DIR/Contents/Resources/RuntimeAtlas.icns"

PLIST_DISPLAY_NAME="$(xml_escape "$DISPLAY_NAME")"
PLIST_VERSION="$(xml_escape "$VERSION")"
PLIST_BUILD_NUMBER="$(xml_escape "$BUILD_NUMBER")"
PLIST_BUILD_COMMIT="$(xml_escape "$BUILD_COMMIT")"
JSON_VERSION="$(json_escape "$VERSION")"
JSON_BUILD_NUMBER="$(json_escape "$BUILD_NUMBER")"
JSON_BUILD_COMMIT="$(json_escape "$BUILD_COMMIT")"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$PLIST_DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ko</string>
    </array>
    <key>CFBundleName</key>
    <string>$PLIST_DISPLAY_NAME</string>
    <key>CFBundleIconFile</key>
    <string>RuntimeAtlas</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$PLIST_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$PLIST_BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Local-only worktree runtime map.</string>
    <key>RuntimeAtlasBuildCommit</key>
    <string>$PLIST_BUILD_COMMIT</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR/Contents/Helpers/$CLI_EXECUTABLE" >/dev/null
codesign --force --deep --sign - "$APP_DIR" >/dev/null
xattr -cr "$APP_DIR" 2>/dev/null || true

VERSIONED_ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"
FIXED_ZIP="$DIST_DIR/$APP_NAME.zip"
(
    cd "$DIST_DIR"
    ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP_NAME.app" "$VERSIONED_ZIP"
)
cp "$VERSIONED_ZIP" "$FIXED_ZIP"

mkdir -p "$PKG_ROOT/Applications" "$PKG_ROOT/usr/local/bin"
ditto "$APP_DIR" "$PKG_ROOT/Applications/$APP_NAME.app"
install -m 0755 "$BIN_DIR/$CLI_EXECUTABLE" "$PKG_ROOT/usr/local/bin/$CLI_EXECUTABLE"
codesign --force --sign - "$PKG_ROOT/usr/local/bin/$CLI_EXECUTABLE" >/dev/null

cat > "$COMPONENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>BundleHasStrictIdentifier</key>
        <true/>
        <key>BundleIsRelocatable</key>
        <false/>
        <key>BundleIsVersionChecked</key>
        <true/>
        <key>BundleOverwriteAction</key>
        <string>upgrade</string>
        <key>RootRelativeBundlePath</key>
        <string>./Applications/$APP_NAME.app</string>
    </dict>
</array>
</plist>
PLIST

VERSIONED_PKG="$DIST_DIR/$APP_NAME-$VERSION.pkg"
FIXED_PKG="$DIST_DIR/$APP_NAME.pkg"
pkgbuild \
    --root "$PKG_ROOT" \
    --component-plist "$COMPONENT_PLIST" \
    --install-location "/" \
    --identifier "$BUNDLE_ID.pkg" \
    --version "$VERSION" \
    "$VERSIONED_PKG" >/dev/null
cp "$VERSIONED_PKG" "$FIXED_PKG"

ZIP_SHA="$(shasum -a 256 "$VERSIONED_ZIP" | awk '{print $1}')"
PKG_SHA="$(shasum -a 256 "$VERSIONED_PKG" | awk '{print $1}')"
cat > "$DIST_DIR/manifest.json" <<JSON
{
  "app": "$APP_NAME.app",
  "build": "$JSON_BUILD_NUMBER",
  "commit": "$JSON_BUILD_COMMIT",
  "latestPkg": "$APP_NAME.pkg",
  "latestZip": "$APP_NAME.zip",
  "pkg": "$APP_NAME-$JSON_VERSION.pkg",
  "pkgSHA256": "$PKG_SHA",
  "version": "$JSON_VERSION",
  "zip": "$APP_NAME-$JSON_VERSION.zip",
  "zipSHA256": "$ZIP_SHA"
}
JSON

rm -rf "$PKG_ROOT"
rm -f "$COMPONENT_PLIST"

echo "Built $APP_DIR"
echo "Built $VERSIONED_ZIP and $FIXED_ZIP"
echo "Built $VERSIONED_PKG and $FIXED_PKG"
