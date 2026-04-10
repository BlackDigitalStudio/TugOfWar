# Tug of War — Design Document

*Source plan for the initial implementation. Written 2026-04-10 from the user's brief. **Revised v2 same day** after the user answered all 12 open questions from v1 — see the "v2 revision log" and "v2 open questions" sections at the bottom.*

## Vision

A cozy, minimalist, top-down real-time strategy game for PC. Small-scale tug-of-war battles where the player and a single AI opponent push a dynamic territory boundary back and forth by spawning units and building structures.

The player is **blue**, the opponent is **red**, the rest of the world is pure **black-and-white**. The tone is calm, unhurried, tactile — lots of subtle feedback on every click. No clutter, no timers, no HUD sprawl.

**First playable target:** one hand-authored level. Win by destroying every enemy building.

## Core gameplay loop

1. The map loads with the player's base at **bottom-left** and the enemy's base at **top-right**, diagonally opposed (matches the orthographic projection).
2. The **ground itself** is the territory: a dynamic blue/red split with a thick rounded dark band where the two colors meet. The band is the "territory line" and it flexes as both sides push.
3. **Build buttons** at the bottom of the screen slowly fill up (cooldowns). When one is ready, the player picks the building up and drops it onto their own territory.
4. **Barracks** spawn melee units automatically; units walk across the line to attack the nearest enemy building — or a **focus target** set by the player.
5. **Towers** defend: they stand still and shoot the nearest enemy unit in range.
6. As a side pushes forward, the territory line bulges into the opponent's color. Losing ground pulls it back.
7. **Win** when every enemy building is destroyed. **Lose** when every player building is destroyed. Level completion is saved.

## Art direction

- **Palette.** Pure black-and-white for the world and props. Blue exclusively for the player, red exclusively for the opponent. No other colors. Feedback effects reuse the same palette via opacity and brightness.
- **Silhouettes.** Thick, rounded, generous black outlines — storybook feel, not inked manga.
- **Forms.** 3D, rounded, chunky, toy-like. No sharp angles. Think polished pebbles and lego-with-round-edges.
- **UI.** Bottom-centered build bar with soft pill-shaped buttons. Cooldowns fill as a liquid inside the pill. Minimal text, maximum icons. No floating numbers in MVP unless unavoidable.
- **Feedback.** Every click → small scale punch, faint white flash, tiny particle puff, soft "tock" sound. Every hover → subtle outline thicken. Every unit hit → brief contrast pulse. Goal: the player feels the game respond to them everywhere.
- **No HP bars.** Unit health is shown only by the unit's own color saturation — fully saturated team color = full HP, fading toward neutral gray as HP drops. Building health works the same way (saturated team color → gray).

## Camera & controls

- **View.** Top-down 3D camera with **orthographic projection** and a slight tilt for depth. No player-controlled rotation.
- **Keyboard pan.** Camera moves on **WASD / arrow keys**. The mouse alone does not pan the camera — this is intentional, so the player can reach for UI pills at the bottom of the screen without the view drifting.
- **Mouse-boosted pan.** While the player is panning via keyboard, if the mouse velocity points in the same direction as the keyboard pan (within ~60° cone), the camera speeds up by ~1.5× — an "I'm trying to go that way" reinforcement. When the keyboard releases, the boost is irrelevant.
- **No mouse drift.** If the keyboard is idle, the camera is idle, no matter where the mouse is. The mouse only drives the screen cursor for clicking on units, buildings, and UI.
- **Zoom.** Scroll wheel (or `+`/`-`) zooms the orthographic size within a small range: roughly **0.7× to 1.5×** of default, in ~0.1× steps.
- **Soft camera bounds.** When the camera is panned far from all gameplay activity ("into the void"), keyboard-driven pan decelerates and asymptotically stops — no hard wall, just a cozy drag that makes infinite empty space feel bounded without being locked. Panning back toward the action releases the drag smoothly.
- **Click actions:**
  - Left-click on empty friendly territory while holding a building → place.
  - Left-click on an enemy building or enemy unit → set it as focus target. See "Focus targeting".
  - Left-click on a ready build-bar pill → pick up the building for placement.
  - Right-click → cancel current placement / clear focus.

## Systems

### The ground (territory field)

The playfield ground **is** the territory visualization. There is no separate ground mesh with a line painted on top — the entire floor of the world is the blue/red split, with the territory line being the thick rounded band where the two colors meet.

**Computation model:**
- Every friendly-owned entity (building + unit) contributes a **claim** to a continuous scalar field. Claim radii differ by entity type: barracks wide, tower medium, unit narrow.
- Blue contributions are positive, red contributions are negative. The summed field is sampled on a grid (or per-pixel in a shader) covering the active play area.
- The ground shader colors each point according to the field sign: positive → saturated blue, negative → saturated red. Near zero is rendered as a **thick, rounded neutral-dark band** — the storybook outline stroke — which automatically traces the border.
- Because the field is continuous and smoothed, the band naturally curves around entity clusters and bulges into whichever side is attacking.
- Buildings and units sit on top of the ground and partially occlude what's beneath them. The band **shows through them slightly** (a small amount of transparency in the silhouette base), so the player feels the line is "flowing under" the world.

**Why this model:** matches the user's exact description — the line IS the ground, rounded, curves around entities, shifts toward the attacker, "slightly visible" through buildings. Simple to tune (radii per entity type). Scales as entity counts grow.

### Buildings

MVP set: **Tower** and **Barracks**.

- **Tower.** Stationary defender. Periodic ranged shot at nearest enemy unit in range. HP, territory claim, destroy animation.
- **Barracks.** Spawns a unit on a steady interval. HP, territory claim, destroy animation.

**Build placement UX (ghost flow):**
1. Click a ready build-bar pill → enter placement mode.
2. A **ghost** of the building appears near the cursor, **not rigidly locked** to it — it trails the cursor with a small amount of spring/ease lag, so it feels alive.
3. Default ghost look: **semi-transparent gray** with an **animated dashed outline** ("marching ants" around the silhouette). This is the "invalid / placeholder" state.
4. When the ghost moves over valid ground (friendly territory, not overlapping any other building), it smoothly tints to the **team color (blue)** and the dashed outline becomes a solid thick blue outline. This is the "ready to place" state.
5. Left-click while valid → the building is placed. Placement plays a soft thud and a small particle puff; the build pill for that building resets its cooldown.
6. Right-click or Escape → cancel placement, ghost fades out.

### Units

MVP: **one melee unit type**.

- Spawns from any friendly barracks on a fixed interval.
- **Default targeting:** walk toward the nearest enemy building; attack on contact.
- **Focus override:** see "Focus targeting" below.
- Simple separation steering so units don't pile into a single column.
- **HP visualization.** The unit's entire silhouette is colored by its team color. Full HP = fully saturated blue/red. As HP drops, saturation fades toward neutral gray. At zero HP the unit dies and is removed. No HP bars, no floating numbers.

### Focus targeting

The player overrides unit target selection by clicking on an enemy **building or unit**.

- Left-click on an enemy **building** → it becomes the focus target.
- Left-click on an enemy **unit** → it becomes the focus target (same mechanic).
- A soft **halo / ring on the ground** appears around the focus target in the player's team color, signaling focus.
- **All friendly units** — currently alive AND spawned after the focus was set — prefer the focused target over their default "nearest enemy building" heuristic. When the focus target dies, units return to default behavior.
- **Cost-priority disambiguation.** When a click lands near BOTH an enemy unit and an enemy building, prefer the **more expensive** one. Rule of thumb: buildings > cheap melee units. A misclick into a cluster near a building will focus the building, not the unit grazing it. This means the click resolution sorts candidate hits by cost descending, not by click distance.
- Right-click or clicking empty friendly territory clears the focus.

### Enemy AI

MVP: **scripted opponent with a gentle ramp**.

- Uses the same cooldown-driven build system as the player (symmetric mechanics).
- **Level 1:** starts with slower cooldowns than the player, giving the player a breathing-room head start. No tower upgrades, no skill activations.
- **Out of MVP (later levels):** faster cooldowns, tower upgrades, skill activations, eventually challenging play.
- **Placement heuristic:** inside own territory, behind the current line, with a small random jitter.
- **Targeting:** default nearest-enemy-building. The AI does not set focus targets in MVP.

### UI

- **Bottom build bar.** Horizontal row of pill buttons, centered. Each pill: icon, cooldown fill (rising liquid), subtle hover label. Ready pills bloom slightly when the cooldown completes.
- **No top HUD.** No resource counters, no minimap in MVP.
- **Focus halo** in the player's team color on the ground around the focus target.
- **Feedback overlays.** Soft click ripple at cursor position on every click. Territory line pulses subtly when the field changes materially.
- **Win / lose card.** Soft desaturation fade → centered card ("You won" / "You lost") → "Play again" button.

### Audio

Soft, Apple-like, minimal, calm. Feedback on almost everything, but quiet enough to never fatigue. MVP sounds:
- Click / button press → soft tock.
- Ghost becomes valid → soft chime.
- Building placed → soft thud.
- Unit spawned → quiet swoosh.
- Unit attack → soft tap.
- Building destroyed → soft crumble.
- Win / lose → soft rising / falling chord.

**Music.** A single simple, very quiet, gently uplifting background loop plays during matches — the kind of tiny melody that lifts spirits without ever competing with the feedback sounds. Soft, unobtrusive, never intrusive. Everything else audio-wise (richer layering, per-event music accents, menu/win/lose music themes) stays out of MVP.

### Save / progression

- **Level progression** is saved. A simple JSON at `user://progress.json` tracks which levels are unlocked and completed. Completing level N unlocks level N+1.
- **Mid-battle state is NOT saved.** Quitting during a battle loses that battle's in-progress state; starting again begins at the start of that level.
- **MVP:** only level 1 exists. The save file is one field ("level_1_complete": true/false), but the code path is generic so adding levels later is trivial.
- Out of MVP: per-level stars, XP, unit/building upgrades carried across levels.

### Win / lose

- Win when `enemy_buildings.size() == 0`.
- Lose when `player_buildings.size() == 0`.
- End → soft desaturation fade, win/lose card, "Play again" button. On win, save progress before showing the card.

## MVP scope (Level 1)

One hand-authored level.

**Layout:**
- Player base: **bottom-left** of the initial camera view.
- Enemy base: **top-right**, diagonally opposed (orthographic projection).
- Ground is the dynamic territory field; there is no separate ground mesh.

**Starting composition (symmetric; AI is handicapped via slow cooldowns):**
- 1 Barracks + 1 Tower per side.
- Build bar with Tower and Barracks pills, both starting partially on cooldown (player pill fills faster than AI's first cooldown).

**"Done" criteria for level 1:**
- Player can place buildings when pills fill.
- Ghost placement UX works (gray dashed → blue solid → placed).
- Units spawn, march, attack, die — HP visualized by color saturation.
- Territory field flexes visibly as sides push.
- Focus targeting works (click enemy → halo, all units re-route, cost-priority disambiguation).
- Enemy AI plays back with slow cooldowns.
- Camera: keyboard pan, mouse boost, zoom, soft cozy bounds.
- One side wins, match ends, "Play again" works, progress saves to `user://progress.json`.
- Every new script has a colocated `*.test.gd` exercising the happy path.

## Phased milestones

**M0 — Scaffolding.** **Done.** `project.godot`, `CLAUDE.md`, `run_tests`, `test_runner.gd`, sanity test green headless.

**M1 — Static scene and camera.** **Done 2026-04-10.** `main.tscn` with orthographic camera rig (`CameraRig` + child `Camera3D`), keyboard pan (WASD + arrows), mouse boost (60° cone, 1.5×), scroll-wheel zoom (0.7–1.5×, 0.1 step), and cozy soft-bound drag past 30 units from origin. Placeholder 200×200 gray ground, two placeholder rounded cylinders at `(-8, 0.75, 8)` (player, blue) and `(8, 0.75, -8)` (enemy, red). All camera math factored into pure static helpers at `scripts/camera/camera_math.gd` with 20 colocated tests. Headless `--quit-after 120` exits 0 with no errors.

**M2 — The ground field.** **Done 2026-04-10.** Spatial shader on a `PlaneMesh` ground evaluates the scalar field per fragment from uniform-array claim data. Hard blue/red zones with 1-2 px AA at the claim radius (no gradient inside a zone), dark territory line drawn only where `F_pos > 0 && F_neg > 0` via pixel-space distance + tip taper for rounded caps. Subtle grid at 2-unit spacing. Camera: position-based mouse boost (persistent), smooth exponential zoom, 30° tilt. MSAA 8x + FXAA, 8192 directional shadow, `soft_shadow_filter_quality=1`, `max_distance=25`. 43/43 tests green.

**M3 — Buildings, build bar, placement.** `Tower` and `Barracks` classes with HP. Build bar widget with cooldown pills. Full ghost placement UX (lag-following, gray dashed → team tint → place).

**M4 — Units and combat.** Melee unit class: movement, default targeting, attack, death. HP-by-saturation shader for units and buildings. Combat resolution.

**M5 — Focus targeting.** Click-to-focus on enemy building or enemy unit; halo ring; cost-priority disambiguation; existing + future unit retarget.

**M6 — Enemy AI.** Scripted opponent with slow cooldowns in level 1.

**M7 — Win/lose, save, first polish pass.** End-of-match flow, "Play again", `user://progress.json`, first art pass toward the rounded cozy look, audio pass.

Each milestone opens with `plans/M<n>_<name>.md`, gets a self-review, and closes with all its `*.test.gd` green.

---

## v2 revision log (resolved v1 questions)

1. **Territory math** → scalar field + zero-isoline rendered as a thick neutral band. ✓
2. **Cursor vs mouse** → **redesigned**. Camera is **keyboard-driven**. Mouse boosts pan speed when moving the same direction as the keyboard. Mouse alone never moves the camera, so UI interactions don't drift the view.
3. **Economy** → cooldowns only in MVP. XP, levels, upgrades come later.
4. **Unit types** → one melee unit. HP shown as team-color saturation (no bars). Same for buildings.
5. **AI sophistication** → scripted; slow cooldowns in level 1 as a head start; skills/upgrades later.
6. **Focus rule** → focus on enemy **buildings or enemy units**. Halo ring on ground in team color. **All** friendly units re-target (existing + future). Cost-priority disambiguation on click (more-expensive target wins a tie).
7. **Level 1 composition** → player **bottom-left**, enemy **top-right diagonal**. Orthographic projection. Symmetric 1 Barracks + 1 Tower per side; AI handicapped via slow cooldowns.
8. **Audio** → soft Apple-like, minimal but pervasive feedback. No music in MVP.
9. **Save / progression** → level completion saved to `user://progress.json`. Mid-battle state **not** saved.
10. **Camera zoom** → yes, small range (~0.7×–1.5× orthographic size).
11. **Ghost placement UX** → lag-follows cursor, gray + animated dashed outline by default, tints to team color when placement is valid, click to place.
12. **Territory line rendering** → the line IS the ground. No separate ground mesh. Line slightly visible through buildings and units ("просвечивает").

## v2 confirmed defaults (user approved 2026-04-10)

- **A. Camera soft bounds on keyboard pan.** Soft cozy deceleration when panning into empty space. Not a hard wall. ✓
- **B. Zoom range.** 0.7×–1.5× of default orthographic size, 0.1× scroll-wheel step. ✓
- **C. Focus halo visual.** Thin pulsing team-color ring flush with the ground at ~1 Hz, radius ≈ 1.3× the focus target's ground footprint. ✓
- **D. Music (added post-v2).** Simple, very quiet, gently uplifting background loop during matches. Soft and never intrusive. ✓

## Checklist

- [x] Design v1 written
- [x] User answered all 12 v1 questions
- [x] Design v2 revised, self-reviewed, v2 open questions listed
- [x] User confirmed v2 A/B/C defaults + requested simple quiet uplifting background music
- [x] Project directory created (`D:\Games\Godot\Projects\tug_of_war`)
- [x] `project.godot` created
- [x] `CLAUDE.md` created
- [x] `run_tests` + `test_runner.gd` + sanity test green headless
- [x] `plans/M1_static_scene.md` opened
- [x] M1 implementation (23/23 tests green, headless `--quit-after 120` clean)
- [x] M2 implementation (43/43 tests green, shader rewritten after user review; ground field, camera upgrades, shadows/AA dialed in)
