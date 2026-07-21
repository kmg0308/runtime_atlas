#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
APP_DIR="$ROOT_DIR/dist/RuntimeAtlas.app"
CLI_HELPER="$APP_DIR/Contents/Helpers/runtime-atlas"

cd "$ROOT_DIR"
bash -n scripts/package.sh scripts/verify.sh
swift test
swift run RuntimeAtlasSelfTest
"$ROOT_DIR/scripts/package.sh"

test -d "$APP_DIR"
test -x "$APP_DIR/Contents/MacOS/RuntimeAtlas"
test -x "$CLI_HELPER"
test -f "$APP_DIR/Contents/Resources/RuntimeAtlas.icns"
test -f "$ROOT_DIR/dist/RuntimeAtlas-$VERSION.zip"
test -f "$ROOT_DIR/dist/RuntimeAtlas-$VERSION.pkg"
test -f "$ROOT_DIR/dist/RuntimeAtlas.zip"
test -f "$ROOT_DIR/dist/RuntimeAtlas.pkg"
test -f "$ROOT_DIR/dist/manifest.json"

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP_DIR/Contents/Info.plist")" = "Runtime Atlas"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_DIR/Contents/Info.plist")" = "RuntimeAtlas"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_DIR/Contents/Info.plist")" = "com.kmg0308.runtimeatlas"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$APP_DIR/Contents/Info.plist")" = "APPL"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_DIR/Contents/Info.plist")" = "13.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleLocalizations:0' "$APP_DIR/Contents/Info.plist")" = "en"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleLocalizations:1' "$APP_DIR/Contents/Info.plist")" = "ko"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" | grep -q '[^[:space:]]'
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist" | grep -q '[^[:space:]]'
/usr/libexec/PlistBuddy -c 'Print :RuntimeAtlasBuildCommit' "$APP_DIR/Contents/Info.plist" >/dev/null
if /usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_DIR/Contents/Info.plist" >/dev/null 2>&1; then
    echo "RuntimeAtlas.app must be a normal windowed app" >&2
    exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :LSBackgroundOnly' "$APP_DIR/Contents/Info.plist" >/dev/null 2>&1; then
    echo "RuntimeAtlas.app must not be background-only" >&2
    exit 1
fi
codesign --verify --deep --strict "$APP_DIR"
codesign --verify --strict "$CLI_HELPER"

unzip -l "$ROOT_DIR/dist/RuntimeAtlas.zip" "RuntimeAtlas.app/Contents/MacOS/RuntimeAtlas" >/dev/null
unzip -l "$ROOT_DIR/dist/RuntimeAtlas.zip" "RuntimeAtlas.app/Contents/Helpers/runtime-atlas" >/dev/null

PKG_CHECK_PARENT="$(mktemp -d)"
PKG_CHECK_DIR="$PKG_CHECK_PARENT/pkg-expanded"
QA_PARENT="$(mktemp -d)"
trap 'rm -rf "$PKG_CHECK_PARENT" "$QA_PARENT"' EXIT

swift run RuntimeAtlasSelfTest --validate-update-archive "$ROOT_DIR/dist/RuntimeAtlas.zip"
printf 'not a zip archive\n' > "$QA_PARENT/invalid-update.zip"
set +e
swift run RuntimeAtlasSelfTest --validate-update-archive "$QA_PARENT/invalid-update.zip" \
    >"$QA_PARENT/invalid-update-stdout" 2>"$QA_PARENT/invalid-update-stderr"
INVALID_UPDATE_EXIT=$?
set -e
test "$INVALID_UPDATE_EXIT" -ne 0
grep -q '^FAIL update archive:' "$QA_PARENT/invalid-update-stderr"

pkgutil --expand-full "$ROOT_DIR/dist/RuntimeAtlas.pkg" "$PKG_CHECK_DIR" >/dev/null
grep -q 'install-location="/"' "$PKG_CHECK_DIR/PackageInfo"
test -d "$PKG_CHECK_DIR/Payload/Applications/RuntimeAtlas.app"
test -x "$PKG_CHECK_DIR/Payload/usr/local/bin/runtime-atlas"
test -x "$PKG_CHECK_DIR/Payload/Applications/RuntimeAtlas.app/Contents/Helpers/runtime-atlas"
grep -q 'relocatable="false"' "$PKG_CHECK_DIR/PackageInfo"

python3 -m json.tool "$ROOT_DIR/dist/manifest.json" >/dev/null
python3 - "$ROOT_DIR/dist/manifest.json" "$VERSION" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
version = sys.argv[2]
expected = {
    "app": "RuntimeAtlas.app",
    "version": version,
    "zip": f"RuntimeAtlas-{version}.zip",
    "pkg": f"RuntimeAtlas-{version}.pkg",
    "latestZip": "RuntimeAtlas.zip",
    "latestPkg": "RuntimeAtlas.pkg",
}
for key, value in expected.items():
    if manifest.get(key) != value:
        raise SystemExit(f"manifest {key} mismatch: {manifest.get(key)!r}")
for key in ("zipSHA256", "pkgSHA256"):
    if len(manifest.get(key, "")) != 64:
        raise SystemExit(f"manifest {key} is not SHA-256")
PY

WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0))' "$WORKFLOW"
grep -q '^  push:' "$WORKFLOW"
grep -q '^  workflow_dispatch:' "$WORKFLOW"
grep -q '^  contents: write$' "$WORKFLOW"
grep -q 'VERSION="0.1.${GITHUB_RUN_NUMBER}"' "$WORKFLOW"
grep -q 'uses: actions/checkout@v6' "$WORKFLOW"
for asset in RuntimeAtlas.zip RuntimeAtlas.pkg 'RuntimeAtlas-${VERSION}.zip' 'RuntimeAtlas-${VERSION}.pkg'; do
    grep -Fq "$asset" "$WORKFLOW"
done
grep -Fq 'https://github.com/kmg0308/runtime_atlas/releases/latest/download/RuntimeAtlas.pkg' "$ROOT_DIR/README.md"
grep -Fq 'https://github.com/kmg0308/runtime_atlas/releases/latest/download/RuntimeAtlas.zip' "$ROOT_DIR/README.md"
grep -Fq 'checks the latest `kmg0308/runtime_atlas` GitHub Release at launch and every 6 hours' "$ROOT_DIR/README.md"
grep -Fq 'GitHubRepository(owner: "kmg0308", name: "runtime_atlas")' "$ROOT_DIR/Sources/RuntimeAtlas/UpdateService.swift"
grep -Fq 'runtimeAtlasBundleIdentifier = "com.kmg0308.runtimeatlas"' "$ROOT_DIR/Sources/RuntimeAtlasCore/UpdateReleasePolicy.swift"
if command -v actionlint >/dev/null 2>&1; then
    actionlint "$WORKFLOW"
else
    echo "actionlint unavailable; YAML parse and Runtime Atlas workflow contract checks passed"
fi

QA_REPO="$QA_PARENT/repository"
QA_DATA="$QA_PARENT/data"
git init -q -b main "$QA_REPO"
git -C "$QA_REPO" -c user.name='Runtime Atlas Tests' -c user.email='runtime-atlas-tests@example.invalid' \
    commit -q --allow-empty -m initial

set +e
QA_OUTPUT="$(cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" verify -- \
    /bin/sh -c 'printf atlas-cli-output; printf atlas-cli-error >&2; exit 7' 2>"$QA_PARENT/stderr")"
QA_EXIT=$?
set -e
test "$QA_EXIT" -eq 7
test "$QA_OUTPUT" = "atlas-cli-output"
test "$(cat "$QA_PARENT/stderr")" = "atlas-cli-error"

(cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" verify -- /usr/bin/true)
(cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" record \
    --kind manual --status BLOCKED --note 'Native app observation blocked' --viewport 980x640)
(cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" record \
    --kind browser --status PENDING --note 'Browser evidence pending')

set +e
(cd "$QA_PARENT" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" record \
    --kind manual --status PENDING --note 'Outside worktree' \
    >"$QA_PARENT/outside-stdout" 2>"$QA_PARENT/outside-stderr")
OUTSIDE_EXIT=$?
(cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" record \
    --kind manual --status PENDING \
    >"$QA_PARENT/usage-stdout" 2>"$QA_PARENT/usage-stderr")
USAGE_EXIT=$?
set -e
test "$OUTSIDE_EXIT" -eq 2
test "$USAGE_EXIT" -eq 64
grep -q 'not inside an available Git worktree' "$QA_PARENT/outside-stderr"
grep -q '^Usage: runtime-atlas record' "$QA_PARENT/usage-stderr"

for index in 1 2 3 4 5 6 7 8; do
    (cd "$QA_REPO" && RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" record \
        --kind manual --status PENDING --note "parallel-$index" >/dev/null) &
done
wait

RUNTIME_ATLAS_HOME="$QA_DATA" "$CLI_HELPER" status --json > "$QA_PARENT/status.json"
python3 -m json.tool "$QA_PARENT/status.json" >/dev/null
python3 - "$QA_DATA/evidence.json" "$QA_PARENT/status.json" <<'PY'
import json
import pathlib
import sys

evidence = json.loads(pathlib.Path(sys.argv[1]).read_text())
status = json.loads(pathlib.Path(sys.argv[2]).read_text())
records = evidence["records"]
if len(records) != 12:
    raise SystemExit(f"expected 12 CLI evidence records, found {len(records)}")
values = {record["status"] for record in records}
if not {"PASS", "FAIL", "BLOCKED", "PENDING"}.issubset(values):
    raise SystemExit(f"missing evidence statuses: {values}")
failed = [record for record in records if record["status"] == "FAIL"]
if len(failed) != 1 or failed[0].get("command") != ["/bin/sh", "-c", "<redacted-shell-script>"]:
    raise SystemExit(f"shell command body was not redacted: {failed}")
if status.get("schemaVersion") != 1 or not isinstance(status.get("repositories"), list):
    raise SystemExit("status --json schema mismatch")
PY

if grep -R -E 'DATABASE_URL|TEST_DATABASE_URL|\.env($|[^A-Za-z])' Sources Tests; then
    echo "Source must not inspect DB URLs or .env files" >&2
    exit 1
fi

echo "verify passed"
