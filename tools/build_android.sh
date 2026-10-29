#!/usr/bin/env bash
# Exports the installable Android APK.
#
# The APK is built for Android 7.0+ (minSdk 24) and targets Android 16
# (API 36), with the 16 KB page-size layout required by newer Android
# devices.  Only the arm64-v8a ABI is packaged: there is no armeabi-v7a,
# x86 or x86_64 library in the APK.
#
# Release builds are signed with a real keystore and verified with
# apksigner (APK Signature Scheme v1, v2 and v3):
#
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore \
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER=footballmaster \
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...' \
#   ANDROID_EXPORT_MODE=release bash tools/build_android.sh
#
# Set ANDROID_EXPORT_MODE=debug to build the throw-away debug-signed APK.
#
# Requirements: Java 17+, the Android SDK (platform-tools + build-tools) and
# the Godot 4.7.2 export templates (downloaded by tools/fetch_godot.sh).
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
[ -d "$SDK/build-tools" ] || die "Android SDK build-tools missing in $SDK; run: sdkmanager 'build-tools;36.0.0' 'platform-tools'"
export ANDROID_HOME="$SDK"

if [ -z "${GODOT_VERSION:-}" ]; then
  GODOT_VERSION="$("$GODOT" --version 2>/dev/null | awk '{print $1}' | cut -d. -f1-3)"
fi
[ -n "$GODOT_VERSION" ] || GODOT_VERSION="4.7.2"

# Godot detects the JDK, the SDK and the debug keystore from a headless editor
# start and stores them in the editor settings.
echo "==> preparing the Godot editor settings"
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true

# Fill in what the detection missed (custom SDK location).
version_minor="${GODOT_VERSION%.*}"
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

# ---------------------------------------------------------------- signing
mode="${ANDROID_EXPORT_MODE:-release}"
case "$mode" in
  release)
    [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] \
      || die "release signing needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD (or use ANDROID_EXPORT_MODE=debug)"
    [ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] \
      || die "release keystore not found: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}" ] || die "GODOT_ANDROID_KEYSTORE_RELEASE_USER is empty"
    [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}" ] || die "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD is empty"
    ;;
  debug)
    # The debug keystore lives outside the project; generate it when Godot
    # did not.
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
    ;;
  *)
    die "ANDROID_EXPORT_MODE must be release or debug, got: $mode"
    ;;
esac

# ---------------------------------------------------------------- export
mkdir -p build/android
echo "==> importing resources"
"$GODOT" --headless --path . --import

apk="build/android/football-master.apk"
rm -f "$apk" "$apk.idsig" build/android/football-master-certificate.pem
if [ "$mode" = "release" ]; then
  echo "==> exporting Android (release, arm64-v8a)"
  "$GODOT" --headless --path . --export-release "Android" "$apk"
else
  echo "==> exporting Android (debug, arm64-v8a)"
  "$GODOT" --headless --path . --export-debug "Android" "$apk"
fi

[ -s "$apk" ] || die "the export produced no APK"

build_tools="${ANDROID_BUILD_TOOLS:+$SDK/build-tools/$ANDROID_BUILD_TOOLS}"
if [ -z "$build_tools" ] || [ ! -d "$build_tools" ]; then
  # Prefer the build-tools that match targetSdk 36; fall back to the newest.
  if [ -d "$SDK/build-tools/36.0.0" ]; then
    build_tools="$SDK/build-tools/36.0.0"
  else
    build_tools="$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
  fi
fi
[ -d "$build_tools" ] || die "no Android build-tools found in $SDK/build-tools"

# Godot signs release exports with the keystore from the environment.  Sign
# once more so the APK always carries v1, v2 and v3 signatures, even when a
# future Godot version changes its default signing flags.
if [ "$mode" = "release" ]; then
  echo "==> signing the APK with v1, v2 and v3 schemes"
  resigned="$apk.resigned"
  "$build_tools/apksigner" sign \
    --ks "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" \
    --ks-key-alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
    --ks-pass "pass:$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" \
    --key-pass "pass:$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --out "$resigned" "$apk" >/dev/null
  mv -f "$resigned" "$apk"
  rm -f "$apk.idsig"
fi

# -------------------------------------------------------------- validate
echo "==> validating $apk"
# aapt 36 prints a benign warning about the template manifest and exits
# non-zero, so the exit status is ignored and the output is what is checked.
badging="$("$build_tools/aapt" dump badging "$apk" 2>/dev/null || true)"
[ -n "$badging" ] || die "aapt could not read the APK"
printf '%s\n' "$badging" | grep -E '^(package|sdkVersion|targetSdkVersion|native-code)'
printf '%s\n' "$badging" | grep -q "package: name='com.mmunki.footballmaster'" \
  || die "the APK has an unexpected package name"

min_sdk="$(printf '%s\n' "$badging" | sed -n "s/^sdkVersion:'\([0-9][0-9]*\)'$/\1/p" | head -1)"
target_sdk="$(printf '%s\n' "$badging" | sed -n "s/^targetSdkVersion:'\([0-9][0-9]*\)'$/\1/p" | head -1)"
[ "$min_sdk" = "24" ] || die "expected minSdk 24 (Android 7.0), got: ${min_sdk:-unknown}"
[ "$target_sdk" = "36" ] || die "expected targetSdk 36 (Android 16), got: ${target_sdk:-unknown}"

native_code="$(printf '%s\n' "$badging" | sed -n 's/^native-code: //p')"
if [ -n "$native_code" ] && [ "$native_code" != "'arm64-v8a'" ]; then
  die "expected arm64-v8a to be the only ABI, got: $native_code"
fi

apk_entries="$(unzip -Z1 "$apk")"
printf '%s\n' "$apk_entries" | grep -qx "lib/arm64-v8a/libgodot_android.so" \
  || die "the APK is missing the arm64-v8a Godot library"
if printf '%s\n' "$apk_entries" | grep -Eq '^lib/(armeabi-v7a|x86|x86_64)/'; then
  die "the APK contains a non-arm64 ABI"
fi
echo "ABI ok: arm64-v8a (no other ABI)"
unzip -t "$apk" >/dev/null || die "the APK zip is corrupt"

# Verify every signature scheme, including the v1 JAR signature.  apksigner
# only checks v1 for minSdk < 24, so pass 23 explicitly to check the files.
signature="$("$build_tools/apksigner" verify --verbose --print-certs --min-sdk-version 23 "$apk" 2>&1)" \
  || die "apksigner rejected the APK signature"
printf '%s\n' "$signature" | grep -q '^Verifies$' || die "APK signature does not verify"
for scheme in 'Verified using v1 scheme (JAR signing): true' \
              'Verified using v2 scheme (APK Signature Scheme v2): true' \
              'Verified using v3 scheme (APK Signature Scheme v3): true'; do
  printf '%s\n' "$signature" | grep -qF "$scheme" || die "missing signature scheme: $scheme"
done

cert_sha="$(printf '%s\n' "$signature" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -1)"
[ -n "$cert_sha" ] || die "could not read the signing certificate"
echo "signature ok: v1 + v2 + v3, certificate SHA-256 $cert_sha"
if [ -n "${ANDROID_EXPECTED_CERT_SHA256:-}" ]; then
  expected="$(printf '%s' "$ANDROID_EXPECTED_CERT_SHA256" | tr -d ':[:space:]' | tr 'A-F' 'a-f')"
  [ "$cert_sha" = "$expected" ] \
    || die "signing certificate mismatch: expected $expected, got $cert_sha"
  echo "certificate fingerprint matches ANDROID_EXPECTED_CERT_SHA256"
fi

# Android 15+ devices can use 16 KB memory pages.  zipalign -P 16 checks that
# the uncompressed native libraries are aligned for such a device.
if "$build_tools/zipalign" -c -P 16 -v 4 "$apk" >/dev/null 2>&1; then
  echo "page size ok: 16 KB aligned"
elif "$build_tools/zipalign" 2>&1 | grep -q -- '-P'; then
  die "the APK is not 16 KB page-size aligned"
else
  echo "warning: this zipalign cannot check 16 KB alignment; skipping"
fi

# Keep the public certificate next to the APK so the signature can be checked
# independently of the keystore.
if [ "$mode" = "release" ]; then
  cert="build/android/football-master-certificate.pem"
  keytool -exportcert -rfc \
    -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" \
    -storepass "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" \
    -alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
    -file "$cert" >/dev/null
  echo "certificate: $cert"
fi

# ------------------------------------------------------------- checksums
touch build/SHA256SUMS
grep -vE 'build/android/football-master\.(apk|certificate\.pem)$' build/SHA256SUMS > build/SHA256SUMS.tmp || true
sha256sum "$apk" >> build/SHA256SUMS.tmp
[ -f build/android/football-master-certificate.pem ] \
  && sha256sum build/android/football-master-certificate.pem >> build/SHA256SUMS.tmp
mv build/SHA256SUMS.tmp build/SHA256SUMS

echo "==> done"
ls -lh "$apk"
cat build/SHA256SUMS
