# Football game — scope and engine decision

Status: **delivered slice (v1.0.0)**.

Goal: a complete, original football game with eFootball-like *gameplay feel*,
sound effects, menus, teams, a stadium, and a reproducible 5h50m-safe build.

It cannot use eFootball, Konami assets, real club badges, real player
likelihoods or licensed music. All names, kits, logos and audio must be
original or properly licensed.

## Engine decision

**Godot 4.4.1** (Track B), Forward+ for desktop, Mobile renderer for phones/Web.

A 10–30 MB package is achievable with Godot 4 using low-poly players, one
stadium, shared materials, compressed textures and Ogg audio — but it will look
stylized, not photoreal.

## Delivered slice (v1.0.0)

- Godot 4.4.1 project (`project.godot`, Forward+).
- Main menu scene + kick-off flow.
- Quick match scene: regulation pitch, goal frames, physics ball, striker,
  camera, stadium lighting, fog and tonemapping.
- Strikers move (WASD/arrows, sprint with Shift) and kick (Space) the ball.
- Goal detection past the goal line; match clock (90 s) and score handling.

## MVP scope still ahead

- Full 11v11 teams, 4 formations, 3 difficulty levels.
- Controls: pass (short/long), through ball, shoot (power/curve), tackle, slide,
  switch player, goalkeeper rush; keyboard + gamepad.
- AI: formation shape, marking, pressing, support runs, goalkeeper positioning.
- Rules: corners, goal kicks, throw-ins, offside, fouls/cards.
- Presentation: team select, HUD, pause, settings, replay of goals.
- Audio: crowd ambience reacting to danger/goals, chants, kicks, whistle, net,
  UI, commentary stingers, music loop.

## Performance and size budgets

| Metric | Desktop | Mobile/Web |
| --- | --- | --- |
| Frame time | 16.6 ms | 33.3 ms |
| Draw calls | 2000 | 800 |
| Triangles | 5M | 1.5M |
| VRAM | 4 GB | 1 GB |
| Package | 10–30 MB (Web) | 10–30 MB |

## Build and delivery

- Every build runs in the checkpointed workflow: 5h30m internal timeout,
  checkpoint upload, continuation run, previous run cancelled.
- Every release contains the game package, `SHA256SUMS`, and the source archive.
