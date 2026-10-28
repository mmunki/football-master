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
