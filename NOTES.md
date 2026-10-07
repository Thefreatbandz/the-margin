# THE MARGIN — dev notes

A cursed-tome survivors-like (Vampire Survivors-style) in Godot 4.7.2.
You are the Scribe; the quill auto-fires ink bolts at the nearest foe.
Gold ink on black pages. Boss: THE REDACTOR every 5 minutes.

## Project layout

- `project.godot` — 720x1280 portrait, `canvas_items` stretch / `expand` aspect,
  `gl_compatibility` renderer (required for web export).
- `scenes/main.tscn` — root node only; `scripts/main.gd` builds the whole
  scene tree in code (`_ready`).
- `scripts/` — `main.gd` (game state, spawner, XP/levels, boss schedule, QA hooks),
  `player.gd` (Scribe: movement, auto-fire, upgrades state), `enemy.gd`
  (typo / shard / blot / scribble / redactor + elites), `bullet.gd`,
  `gem.gd` (ink drops + magnet vacuum), `bg.gd` (ruled page background),
  `hud.gd`, `joystick.gd` (fixed bottom-left, touch + mouse), `levelup.gd`
  (3 upgrade cards, pauses the tree), `sfx.gd` (pooled SFX), `ringfx.gd`
  (ink-nova ring).
- `audio/` — procedural WAVs; regenerate with `python3 tools/gen_sfx.py`.
- `art/` — v2 sprite art (gold-ink-on-black etchings, 512px RGBA): scribe, quill,
  page_shard, ink_blot, margin_scribble, redactor, ink_gem, flourish.
  Shared via `main.gd`'s `ART` const (preloaded once, never duplicated).
- `art/v3/` — v3 figure parts (512px RGBA, tight-cropped; 1024px originals in
  `art/v3/src/`, gitignored): scribe_torso/hood/arm_r/arm_l/panel_l/panel_r,
  blot_body/tendril_l/r, scribble_body/legs_l/r, shard_body/wing,
  redactor_torso/head/arm_l/r. White-bg generations keyed via edge flood-fill
  (`/tmp/key_white.py`); verified clean on black before shipping.
- `scripts/rig.gd` — v3 skeletal rigs: builds Skeleton2D + Bone2D hierarchies
  with rigid Sprite2D parts parented to bones (no skinning — cheap at 150
  enemies) + AnimationPlayer with eased keyframes, all in code.
  Scribe: Hips>Torso>Head/ArmL, Hips>PanelL/R, plus an aim-driven AimPivot for
  the quill arm (rotation = live aim; attack anim punches position only).
  Anims: idle/walk/attack/hit/die (scribe); move/lunge/hit/die (enemies);
  move/slam_windup/slam/hit/die (redactor). Enemies face the player
  (head toward prey); boss slam: 0.7s telegraphed wind-up, then smash +
  ring FX + 38 dmg within 165px, 4.5s cooldown. Player death: 0.55s crumple
  before the death screen (timer-based, is_instance_valid-guarded).
  Known Godot 4.7 quirk: one benign `det == 0` engine warning per Bone2D on
  first setup (rendering unaffected).
- `export_presets.cfg` — `Web` preset, `variant/thread_support=false`
  (nothreads template: runs on plain static hosting, no COOP/COEP headers).
- `build/` (gitignored) — export staging. `docs/` — the shipped web build
  (GitHub Pages serves `/docs`). `qa/` (gitignored) — QA screenshots.

## Run in the Godot editor

Open Godot 4.7.2 → Import → pick `~/workspace/margin/project.godot` → Play.
No input map is used: movement is `Input.is_physical_key_pressed` (WASD/arrows)
plus the on-screen joystick, so nothing needs configuring.

## Headless QA hooks (command-line user args, never active in the shipped game)

- `-- --shots` — scripted run under Xvfb that saves `qa/title.png`,
  `qa/gameplay.png`, `qa/levelup.png`, `qa/boss.png` then quits:
  `xvfb-run -a ~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 720x1280 -- --shots`
- `-- --autotest` — 30s game-time soak at 8x with auto-picked upgrades,
  prints `AUTOTEST_SUMMARY` (kills/level/enemies/...) then quits.
- `-- --soak` — 150s game-time soak, same summary. Add `--realtime` to run
  at 1x (honest balance signal; 8x tunnels bullets through enemies).
  Prints `SOAKDBG` lines every 30s in soak mode.
- `-- --deathshot` — verifies the death screen + restart button: force-kills
  the Scribe, saves `qa/death.png`, presses restart (scene reload), saves
  `qa/restarted.png` once the fresh run is playing.

## Export (headless)

```
~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --export-release "Web" build/web/index.html
```

If you add/remove audio or scripts, run an import pass first:
`... --headless --path . --import`

## Deploy

```
# 1. copy the fresh export into docs/
rm -rf docs && mkdir -p docs && cp -r build/web/* docs/
# 2. commit + push (repo: Thefreatbandz/the-margin, branch main)
git add -A && git commit -m "vX: ..." && git push origin main
# 3. Pages is already configured (main branch, /docs folder) — the live
#    link https://thefreatbandz.github.io/the-margin/ updates in ~1 min.
```

First-time Pages enable (already done for this repo):
`gh api repos/Thefreatbandz/the-margin/pages -X POST -f 'source[branch]=main' -f 'source[path]=/docs'`

## Tuning knobs (all in `scripts/main.gd` / `player.gd`)

- `ETYPES` — per-kind hp/spd/dmg/xp/radius/unlock-time/weight.
  (typo 16/88/6, shard 46/82/14 @45s, blot 95/64/20 @110s, scribble 160/122/26 @180s;
  elites 9x hp after 100s.)
- HP scale: `1 + (run_time/60) * 0.35`; spawn interval `max(0.18, 0.7 - t*0.0013)`,
  batch `1 + t/70` (cap 6); `MAX_ENEMIES = 150`.
- `BOSS_EVERY = 300.0`; boss hp `2400 * (1 + 0.85*boss_count)`.
- `UPGRADES` pool + `apply_upgrade()`; `xp_for_level(lv) = 8 + (lv-1)*6`.
- Player base stats in `player.gd` (`reset()`): 110 HP, 305 speed, 12 dmg,
  2.2 shots/s, 140 magnet, 0.75s iframes. Bullets shove enemies 14px.
