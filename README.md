# Football Master

**Football Master** is an original 3D football game built with **Godot 4**.

It is an independent, original football game with an eFootball-like *gameplay
feel*: a regulation pitch, goal frames, physics ball, a player striker and a
real-time clock. It does not use any Konami/eFootball asset, name or audio.

## Status

The project now contains the first playable slice of the game:

- `scenes/menu.tscn` — main menu (title, kick-off button, controls).
- `scenes/match.tscn` — quick match scene: stadium ground, regulation pitch,
  2 goal frames, striker character, physics ball, camera, lighting.
- `scripts/` — menu, match controller, striker (movement/sprint/kick) and ball
  (physics + goal detection).

## Run locally

```bash
bash tools/fetch_godot.sh        # prints the editor path
export GODOT="$(bash tools/fetch_godot.sh | tail -1)"
bash tools/build.sh
```

## Build and release

The release pipeline lives in `tools/build.sh` (Linux + Web export, headless
smoke test, packaging, SHA-256) and `.github/workflows/build.yml` (Godot 4 build
with the 5h50m checkpoint rule).

## Android APK

`tools/build_android.sh` exports the Android APK. It needs Java 17+, the
Android SDK (`platform-tools` and `build-tools`) and, on a fresh machine, the
Godot 4.7.2 export templates that `tools/fetch_godot.sh` downloads.

```bash
export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64
export ANDROID_HOME=/usr/local/lib/android/sdk
sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"
bash tools/build_android.sh      # -> build/android/football-master.apk
adb install -r build/android/football-master.apk
```

The APK contains **only the `arm64-v8a` ABI** (no `armeabi-v7a`, `x86` or
`x86_64` libraries), runs on **Android 7.0+** (minSdk 24) and targets
**Android 16** (targetSdk 36). The native libraries and the APK use the
**16 KB page-size** layout required by newer Android devices. The mobile
renderer uses Vulkan on Android 7.0+ and falls back to OpenGL ES 3 on older
devices. On a phone the left thumb stick moves the striker (push it all the
way to sprint) and the KICK button shoots.

Release builds are **release-signed** (not debug-signed) and verified with
`apksigner` using APK Signature Scheme v1, v2 and v3:

```bash
export ANDROID_EXPORT_MODE=release
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=footballmaster
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'
bash tools/build_android.sh
```

`tools/build_android.sh` refuses to build a release without a keystore. It
writes the public certificate to `build/android/football-master-certificate.pem`,
checks that the only ABI is arm64-v8a, that minSdk/targetSdk are 24/36, that
the APK is 16 KB aligned, and that the v1/v2/v3 signatures verify. Set
`ANDROID_EXPORT_MODE=debug` only for a throw-away test build.

CI (`.github/workflows/android.yml`) rebuilds and verifies the APK on every
relevant change. It reads the keystore from the repository secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`
and `ANDROID_CERT_SHA256`, and keeps the APK, certificate and checksums as
artifacts.

```bash
.github/scripts/publish-release.sh \
    --repo mmunki/football-master --clone https://github.com/mmunki/football-master \
    --branch main --build "bash tools/build.sh" \
    --artifact build/football-master-linux.zip \
    --artifact build/football-master-web.zip \
    --source-archive \
    --tag v1.0.0 --name "Football Master 1.0.0" --notes "..."
```

## Quality gates

```bash
python3 tools/validate_assets.py --strict
python3 tools/perf_budget.py
```
