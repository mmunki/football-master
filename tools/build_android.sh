#!/usr/bin/env bash
# Exports the installable Android APK.
#
# The APK is debug-signed with the throw-away Godot debug keystore, which is
# fine for sideloading and testing.  Set GODOT_ANDROID_KEYSTORE_RELEASE_PATH,
# GODOT_ANDROID_KEYSTORE_RELEASE_USER and GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# and run with ANDROID_EXPORT_MODE=release to publish a release-signed build.
#
# Requirements: Java 17+, the Android SDK (platform-tools + build-tools) and
# the Godot 4.4.1 export templates (downloaded by tools/fetch_godot.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ -z "${GODOT:-}" ]; then
  GODOT="$(bash tools/fetch_godot.sh | tail -1)"
fi
[ -x "$GODOT" ] || die "Godot not executable: $GODOT"

# --------------------------------------------------------------- toolchain
if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in /usr/lib/jvm/temurin-17-jdk-amd64 /usr/lib/jvm/java-17-openjdk-amd64; do
    [ -x "$candidate/bin/java" ] && JAVA_HOME="$candidate" && break
  done
fi
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME
command -v java >/dev/null 2>&1 || [ -x "${JAVA_HOME:-}/bin/java" ] \
  || die "Java 17+ is required (set JAVA_HOME)."

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ]; then
  for candidate in "$HOME/Android/Sdk" /usr/local/lib/android/sdk /opt/android-sdk; do
    [ -d "$candidate/platform-tools" ] && SDK="$candidate" && break
  done
fi
[ -n "$SDK" ] || die "Android SDK not found (set ANDROID_HOME)."
[ -d "$SDK/platform-tools" ] || die "Android SDK platform-tools missing in $SDK"
[ -d "$SDK/build-tools" ] || die "Android SDK build-tools missing in $SDK; run: sdkmanager 'build-tools;34.0.0' 'platform-tools'"
export ANDROID_HOME="$SDK"

# Godot detects the JDK, the SDK and the debug keystore from a headless editor
# start and stores them in the editor settings.
echo "==> preparing the Godot editor settings"
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true

# Fill in what the detection missed (custom SDK location).
version_minor="${GODOT_VERSION:-4.4.1}"; version_minor="${version_minor%.*}"
settings="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-${version_minor}.tres"
if [ -f "$settings" ]; then
  python3 - "$settings" "$SDK" "${JAVA_HOME:-}" <<'PY'
import pathlib
import sys

path, sdk, java = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text()
missing = []
if "export/android/android_sdk_path = " not in text:
    missing.append(f'export/android/android_sdk_path = "{sdk}"')
if java and "export/android/java_sdk_path = " not in text:
    missing.append(f'export/android/java_sdk_path = "{java}"')
if missing:
    path.write_text(text.rstrip("\n") + "\n" + "\n".join(missing) + "\n")
PY
fi

# The debug keystore lives outside the project; generate it when Godot did not.
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
keystore="$data_home/godot/keystores/debug.keystore"
if [ ! -f "$keystore" ]; then
  echo "==> creating the Android debug keystore"
  mkdir -p "$(dirname "$keystore")"
  keytool -genkeypair -keystore "$keystore" -storepass android \
    -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "cn=Android Debug, o=Android, c=US" >/dev/null
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

# ---------------------------------------------------------------- export
mkdir -p build/android
echo "==> importing resources"
"$GODOT" --headless --path . --import

if [ "${ANDROID_EXPORT_MODE:-debug}" = "release" ]; then
  [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] \
    || die "ANDROID_EXPORT_MODE=release needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD"
  echo "==> exporting Android (release-signed)"
  "$GODOT" --headless --path . --export-release "Android" build/android/football-master.apk
else
  echo "==> exporting Android (debug-signed)"
  "$GODOT" --headless --path . --export-debug "Android" build/android/football-master.apk
fi

apk="build/android/football-master.apk"
[ -s "$apk" ] || die "the export produced no APK"

# -------------------------------------------------------------- validate
build_tools="$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
[ -n "$build_tools" ] || die "no Android build-tools found in $SDK/build-tools"
echo "==> validating $apk"
# aapt 34 prints a benign warning about the template manifest and exits
# non-zero, so the exit status is ignored and the output is what is checked.
badging="$("$build_tools/aapt" dump badging "$apk" 2>/dev/null || true)"
[ -n "$badging" ] || die "aapt could not read the APK"
printf '%s\n' "$badging" | grep -E '^(package|sdkVersion|targetSdkVersion)'
printf '%s\n' "$badging" | grep -q "package: name='com.mmunki.footballmaster'" \
  || die "the APK has an unexpected package name"
"$build_tools/apksigner" verify --verbose "$apk" >/dev/null 2>&1 \
  || die "apksigner rejected the APK signature"

apk_entries="$(unzip -Z1 "$apk")"
for abi in arm64-v8a armeabi-v7a x86_64; do
  printf '%s\n' "$apk_entries" | grep -qx "lib/$abi/libgodot_android.so" \
    || die "the APK is missing the $abi Godot library"
  echo "ABI ok: $abi"
done
unzip -t "$apk" >/dev/null || die "the APK zip is corrupt"

# ------------------------------------------------------------- checksums
touch build/SHA256SUMS
grep -v "build/android/football-master.apk" build/SHA256SUMS > build/SHA256SUMS.tmp || true
sha256sum "$apk" >> build/SHA256SUMS.tmp
mv build/SHA256SUMS.tmp build/SHA256SUMS

echo "==> done"
ls -lh "$apk"
cat build/SHA256SUMS
