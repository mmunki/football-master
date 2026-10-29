#!/usr/bin/env bash
# Downloads a pinned Godot 4 editor + export templates and prints the editor
# path.  Everything is cached, so a continuation run pays the download only
# once (the cache directory is part of the build checkpoint).
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
RELEASE="${VERSION}-stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${GODOT_CACHE:-$ROOT/.cache/godot}"

mkdir -p "$CACHE"

editor="$CACHE/Godot_v${RELEASE}_linux.x86_64"
if [ ! -x "$editor" ]; then
  echo "downloading Godot $VERSION editor" >&2
  curl -fsSL --retry 3 -o "$CACHE/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${RELEASE}/Godot_v${RELEASE}_linux.x86_64.zip"
  unzip -q -o "$CACHE/godot.zip" -d "$CACHE"
  chmod +x "$editor"
fi

templates="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
if [ ! -f "$templates/linux_release.x86_64" ] \
    || [ ! -f "$templates/web_release.zip" ] \
    || [ ! -f "$templates/android_release.apk" ] \
    || [ ! -f "$templates/android_debug.apk" ]; then
  echo "downloading Godot $VERSION export templates" >&2
  curl -fsSL --retry 3 -o "$CACHE/templates.tpz" \
    "https://github.com/godotengine/godot/releases/download/${RELEASE}/Godot_v${RELEASE}_export_templates.tpz"
  rm -rf "$CACHE/templates"
  mkdir -p "$CACHE/templates"
  unzip -q -o "$CACHE/templates.tpz" -d "$CACHE/templates"
  mkdir -p "$templates"
  cp -a "$CACHE/templates/templates/." "$templates/"
fi

printf '%s\n' "$editor"
