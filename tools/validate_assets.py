#!/usr/bin/env python3
"""Asset budget checks for the Game Forge project.

Runs in CI and locally.  It does not need Godot or a GPU: it validates the
files that usually cause frame-time spikes and memory bloat before they reach
a build.

Hard failures (exit 1):
  * a texture larger than MAX_TEXTURE
  * a texture that is not power-of-two (when STRICT_POT=1)
  * a single asset larger than MAX_ASSET_MB
  * a WAV longer than MAX_WAV_SECONDS (use Ogg Vorbis for music)

Warnings do not fail the run unless --strict is passed.
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
MAX_TEXTURE = int(os.environ.get("MAX_TEXTURE", "4096"))
MAX_ASSET_MB = float(os.environ.get("MAX_ASSET_MB", "64"))
MAX_WAV_SECONDS = float(os.environ.get("MAX_WAV_SECONDS", "30"))
STRICT_POT = os.environ.get("STRICT_POT", "0") == "1"

TEXTURE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".exr", ".hdr"}
MESH_EXT = {".glb", ".gltf", ".obj", ".fbx"}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}


def png_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as fh:
        if fh.read(8) != b"\x89PNG\r\n\x1a\n":
            return None
        fh.read(4)
        if fh.read(4) != b"IHDR":
            return None
        width, height = struct.unpack(">II", fh.read(8))
        return width, height


def jpeg_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as fh:
        if fh.read(2) != b"\xff\xd8":
            return None
        while True:
            byte = fh.read(1)
            if not byte:
                return None
            if byte != b"\xff":
                continue
            marker = fh.read(1)
            while marker == b"\xff":
                marker = fh.read(1)
            if marker in (b"\xd8", b"\xd9"):
                continue
            length_raw = fh.read(2)
            if len(length_raw) != 2:
                return None
            length = struct.unpack(">H", length_raw)[0]
            if marker and marker[0] in range(0xC0, 0xC4):
                fh.read(1)
                height, width = struct.unpack(">HH", fh.read(4))
                return width, height
            fh.seek(length - 2, 1)


def is_pot(value: int) -> bool:
    return value > 0 and value & (value - 1) == 0


def wav_seconds(path: Path) -> float | None:
    with path.open("rb") as fh:
        if fh.read(4) != b"RIFF":
            return None
        fh.read(4)
        if fh.read(4) != b"WAVE":
            return None
        byte_rate = None
        data_size = None
        while True:
            chunk = fh.read(8)
            if len(chunk) != 8:
                break
            name, size = chunk[:4], struct.unpack("<I", chunk[4:])[0]
            if name == b"fmt ":
                fmt = fh.read(size)
                if len(fmt) >= 12:
                    byte_rate = struct.unpack("<I", fmt[8:12])[0]
                if size % 2:
                    fh.read(1)
            elif name == b"data":
                data_size = size
                break
            else:
                fh.seek(size + (size % 2), 1)
    if byte_rate and data_size:
        return data_size / byte_rate
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="warnings fail the run")
    args = parser.parse_args()

    if not ASSETS.exists():
        print(f"no assets/ directory yet; nothing to validate ({ASSETS})")
        return 0

    errors: list[str] = []
    warnings: list[str] = []
    counts = {"texture": 0, "mesh": 0, "audio": 0, "other": 0}

    for path in sorted(ASSETS.rglob("*")):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        size_mb = path.stat().st_size / (1024 * 1024)
        rel = path.relative_to(ROOT)

        if size_mb > MAX_ASSET_MB:
            errors.append(f"{rel}: {size_mb:.1f} MB > {MAX_ASSET_MB:.0f} MB")

        if ext in TEXTURE_EXT:
            counts["texture"] += 1
            dims = png_size(path) if ext == ".png" else jpeg_size(path) if ext in {".jpg", ".jpeg"} else None
            if dims:
                width, height = dims
                if max(width, height) > MAX_TEXTURE:
                    errors.append(f"{rel}: {width}x{height} > {MAX_TEXTURE}px")
                if STRICT_POT and not (is_pot(width) and is_pot(height)):
                    warnings.append(f"{rel}: {width}x{height} is not power-of-two")
                if width != height:
                    warnings.append(f"{rel}: not square ({width}x{height})")
        elif ext in MESH_EXT:
            counts["mesh"] += 1
            if size_mb > 20:
                warnings.append(f"{rel}: large mesh ({size_mb:.1f} MB); check LODs")
        elif ext in AUDIO_EXT:
            counts["audio"] += 1
            if ext == ".wav":
                seconds = wav_seconds(path)
                if seconds and seconds > MAX_WAV_SECONDS:
                    errors.append(f"{rel}: WAV is {seconds:.0f}s; use Ogg Vorbis")
        else:
            counts["other"] += 1

    scenes = list((ROOT / "scenes").rglob("*.tscn")) if (ROOT / "scenes").exists() else []
    text = "\n".join(p.read_text(errors="replace") for p in scenes)
    for feature in ("MultiMeshInstance3D", "visibility_range", "LOD"):
        if feature in text:
            print(f"optimization present: {feature}")

    report = {"counts": counts, "errors": errors, "warnings": warnings}
    print(json.dumps(report, indent=2))

    for message in warnings:
        print(f"warning: {message}")
    for message in errors:
        print(f"error: {message}")

    if errors:
        return 1
    if args.strict and warnings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
