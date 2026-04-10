# M3 — Buildings, build bar, placement

*Milestone plan. Scope: replace the M2 placeholder cylinders with real `Tower` and `Barracks` classes that have HP and teams; add a bottom-screen build bar with cooldown pill buttons; let the player drag a lag-following ghost preview of a building across the ground and drop it on valid friendly territory. No combat yet — that lands in M4.*

## Goals

- `Building` base class that owns HP, team, claim radius/sign, and self-registration with `TerritoryField`. Replaces `building_placeholder.gd` entirely.
- `Tower` and `Barracks` subclasses. For M3 their differences are only visual (mesh, color accent) + a few placeholder export params. Their combat/spawn behavior is stubbed — it lands in M4.
- `BuildBar` — a bottom-centered `CanvasLayer` with one pill per building type. Each pill has a cooldown that fills over time and a "ready → pick up" state.
- `PlacementController` + `GhostBuilding` — when the player clicks a ready pill, a semi-transparent ghost of the building spawns and follows the cursor with spring/ease lag. The ghost is gray with an animated dashed outline when the drop is invalid, and solid team-color when the drop is valid. Left-click places a real `Tower` / `Barracks` at the ghost's position and resets the pill's cooldown. Right-click or Escape cancels.
- Placement validity rule (M3): the ghost's position must (a) be on friendly territory (scalar field `F > 0` for player) AND (b) not overlap any existing building within a minimum distance.
- All new scripts get colocated `*.test.gd` files. `building_math.gd` holds the pure, testable placement-validity helpers and cooldown math; the scene/tree-bound scripts stay thin.
- `building_placeholder.gd` is deleted at the end of M3 — no orphan placeholders left in the tree.
- `./run_tests` stays green. Headless `--quit-after 120` stays clean.
- Visual run: the player can click a pill, see the ghost trail the cursor with a little spring lag, color-shift gray↔blue as it crosses territory, left-click to place, and watch the new building register as a claim in the territory shader (the zone bulges toward the placement site).

## Out of scope for M3

- Unit entities (M4).
- Real attack logic on Tower (M4).
- Real spawn logic on Barracks (M4).
- Focus targeting (M5).
- Enemy AI (M6).
- Win / lose / save (M7).
- Audio.
- Fancy dashed-outline shader for the ghost — for M3 the "dashed outline" can be a simple animated line/border using a ShaderMaterial on the ghost mesh, OR (simpler) just an alpha pulse for the invalid state. Good-enough outline polish can come with the M7 art pass.

## Architecture

```
scripts/buildings/
├── building.gd            # base class Node3D: HP, team, claim, register
├── building.test.gd       # HP math, team sign, take_damage, destroy signal
├── tower.gd               # extends Building; M3-stub combat params
├── barracks.gd            # extends Building; M3-stub spawn params
└── building_math.gd       # pure placement-validity + cooldown helpers
    └── building_math.test.gd

scripts/ui/
├── build_bar.gd           # CanvasLayer; owns a list of BuildPills
├── build_pill.gd          # single pill; cooldown fill; click → PlacementController
└── build_pill.test.gd     # cooldown progression

scripts/placement/
├── placement_controller.gd  # orchestrates: click pill → spawn ghost → handle input → place or cancel
├── ghost_building.gd        # visual ghost; lag-follows a target world point
└── ghost_building.test.gd   # spring-ease math (delegated to a helper)

scenes/
├── main.tscn               # replaces placeholder cylinders with Tower + Barracks;
│                           # adds BuildBar CanvasLayer + PlacementController node
├── tower.tscn              # prefab: Tower root + mesh + material
└── barracks.tscn           # prefab: Barracks root + mesh + material
```

### Class contract for `Building` (duck-typed for TerritoryField)

```gdscript
class_name Building
extends Node3D

enum Team { PLAYER, ENEMY }

@export var team: Team = Team.PLAYER
@export var max_hp: int = 100
@export var claim_radius: float = 14.0

var hp: int
var team_sign: float:   # computed from team; matches placeholder contract
    get: return 1.0 if team == Team.PLAYER else -1.0

signal hp_changed(new_hp: int, max_hp: int)
signal destroyed()

func take_damage(amount: int) -> void: ...
func destroy() -> void: ...
```

TerritoryField auto-registers Buildings on `_enter_tree` (same duck contract as the placeholder: `global_position`, `claim_radius`, `team_sign`).

### BuildBar UX

- Sits in a `CanvasLayer` at the bottom of the viewport.
- Two pills: Tower and Barracks (in that order; left to right).
- Each pill shows an icon placeholder (a simple colored square for M3; icon art comes later), a vertical cooldown fill rising from the bottom, and a subtle ready-bloom when the fill completes.
- Click a ready pill → `PlacementController.start_placement(building_type)`. The pill enters "held" state (greyed out until the placement is completed or cancelled).
- Cooldown is a `Timer`-like state: `remaining: float` decreasing each frame; when `remaining <= 0`, ready.
- After a successful placement, the pill's cooldown resets to the building type's `build_cooldown` (e.g. 8.0s for M3).

### PlacementController + GhostBuilding

- `PlacementController` is a Node in main.tscn. It maintains state: idle, placing.
- On `start_placement(type)`:
  - Instantiates a `GhostBuilding` node configured for that type (mesh, size).
  - Sets its target follow position via raycast from cursor to the ground plane.
  - Starts handling `_input` for mouse motion, clicks, right-click, Escape.
- Each frame in placing state:
  - Computes the **target world point** by raycasting the mouse ray against a flat Y=0 plane.
  - Smoothly eases the ghost toward the target point (spring-lag, NOT rigid lock).
  - Recomputes the validity factor (on friendly territory + no overlap).
  - Pushes the validity into the ghost's shader or material parameters.
- On left-click: if valid → instantiate the real building at the ghost's current position, fire `pill.reset_cooldown()`, exit placing state, free the ghost.
- On right-click / Escape / click on UI: exit placing state, free the ghost, leave the pill cooldown unchanged.

### GhostBuilding visual

For M3 keep it simple: a MeshInstance3D using the same mesh as the real building, with a dedicated ShaderMaterial that:
- Uses transparency (`render_mode blend_mix`).
- Has an `is_valid: bool` uniform.
- When invalid: albedo = gray `(0.6, 0.6, 0.6)`, alpha ~0.5, with a simple dashed-outline effect (a cheap `fract(TIME * speed + world_normal * ...)` trick for animated dashes, or just a pulsing alpha).
- When valid: albedo = team color, alpha ~0.6, solid (no dashes).

The full animated-dashes shader is a nice-to-have; acceptable fallback: a timed alpha pulse (invalid state slowly blinks). The design doc's aspiration can be satisfied properly in the M7 polish pass.

## Tuning defaults (M3)

| Parameter | Default | Notes |
|---|---|---|
| `Building.max_hp` (Tower) | 80 | smaller defender HP |
| `Building.max_hp` (Barracks) | 140 | larger spawner HP |
| `Tower.claim_radius` | 10.0 | narrower claim |
| `Barracks.claim_radius` | 14.0 | wider claim (matches M2 defaults) |
| Tower build cooldown | 6.0 s | |
| Barracks build cooldown | 9.0 s | |
| Starting cooldowns (level 1) | 3.0 / 4.5 s | half-filled at scene start |
| Ghost follow smoothing | 12.0 (exp) | per-second blend rate toward cursor target |
| Minimum placement distance from other buildings | 2.5 units | center-to-center |
| Placement raycast max length | 200 units | plenty |

## Steps (execution order)

1. **Write `building.gd`** with HP math, enter/exit tree registration, signals, `take_damage`, `destroy`.
2. **Write `building_math.gd`** with pure helpers:
   - `is_on_friendly_territory(field_value, friendly_sign) -> bool`
   - `is_clear_of_buildings(candidate: Vector2, existing: Array[Vector2], min_distance: float) -> bool`
   - `advance_cooldown(remaining: float, delta: float) -> float`
   - `cooldown_fill_fraction(remaining: float, total: float) -> float`
3. **Write `building.test.gd` + `building_math.test.gd`**.
4. **Write `tower.gd` + `barracks.gd`** (minimal subclasses, just defaults and type identity).
5. **Replace `main.tscn` cylinders with a Tower node and a Barracks node** using the same visual mesh as before. Debug orbit on the enemy barracks still works (since Barracks inherits from Building which doesn't restrict `_process`, I'll carry the orbit logic into a small debug component or inline it on Barracks with a guard).
6. **Delete `scripts/buildings/building_placeholder.gd`** once main.tscn no longer references it.
7. **Write `build_pill.gd` + `build_bar.gd`** + their tests for the pure cooldown progression.
8. **Wire up the BuildBar in main.tscn** as a `CanvasLayer` with two pills.
9. **Write `placement_controller.gd` + `ghost_building.gd`**.
10. **Write the ghost placement shader** (minimal: gray invalid ↔ team-color valid, alpha ~0.5). Dashed animation is optional M3 nice-to-have.
11. **Wire PlacementController into main.tscn** and connect it to BuildBar.
12. **End-to-end testing:** `bash ./run_tests` → all green; headless `--quit-after 120` → exit 0; visual launch; verify the flow:
    - Click a ready pill
    - Ghost appears and trails the cursor smoothly
    - Ghost is gray over enemy territory, blue over friendly
    - Left-click on friendly territory → real building spawns there, cooldown resets
    - The territory field visibly bulges toward the new building

## Self-review (before coding)

- **Building vs BuildingPlaceholder contract.** The placeholder has `global_position`, `claim_radius`, `team_sign`. The new Building class must match this duck-type so `TerritoryField.sync_to_material` keeps working without changes. Confirmed: plan above uses the same names.

- **Enemy barracks debug orbit.** M2 used a `debug_orbit_enabled` flag on the placeholder to orbit the enemy cylinder. That orbit is what made the territory field visibly update. If I strip the placeholder, I lose the orbit. Two options: (a) keep a tiny `scripts/debug/orbit.gd` component that attaches to any Node3D and orbits it; (b) inline the orbit in Barracks with a guard. **Going with (a)** — cleaner separation, debug code doesn't leak into the gameplay class. The orbit script will get deleted in M4 when real units make the territory dynamic naturally.

- **Ghost placement on a tilted orthographic camera.** I need to raycast a screen point to the ground plane (Y=0). With an orthographic camera, `project_ray_origin` and `project_ray_normal` still work correctly — I intersect that ray with the Y=0 plane algebraically. No physics engine needed.

- **Validity check uses TerritoryField, but TerritoryField doesn't expose a `field_at(point)` method on the autoload** — only `sync_to_material` and `snapshot_claims`. I'll add a thin `field_at(Vector2) -> float` wrapper on the autoload that reuses `TerritoryMath.field_at` over the current claims. This is a tiny API addition and is worth a test.

- **Overlap check.** I need the list of current buildings to compare distance. I'll use `get_tree().get_nodes_in_group("buildings")` and add buildings to the "buildings" group in `_enter_tree`. Alternative: maintain a static `Building.all_buildings` array. Groups are cleaner.

- **BuildBar input vs camera input.** The camera rig reads `Input.is_key_pressed` directly (not action-based). UI interaction via mouse needs to NOT pan the camera. Since the camera only pans on keyboard, clicking the BuildBar pills won't accidentally pan. ✓

- **Cost-priority disambiguation (from design doc).** That's a M5 feature (focus targeting), not M3. Placement clicks hit the ground via raycast; no disambiguation needed here.

- **Camera soft-bound centroid refactor (deferred from M2).** This was the planned M1→M2 refactor that I deferred to M3. Do I do it here? Strictly yes, since real buildings exist now. However, M3 is already a big milestone with placement UX. I'm deferring ONCE MORE to M4 (after units land), OR to a small M3 cleanup step. **Decision: leave as-is for now; note the deferral AGAIN in the "deferred" section below and revisit if the user notices**. The current origin-based soft-bound works fine in practice for a single-level scene and doesn't block gameplay.

- **What if the ghost's position isn't on the ground plane yet (tree not ready)?** Guard by initializing ghost target to the rig's position or the last known camera-look-at point. Never leave ghost at world origin (visible jump).

- **Test isolation for Building / TerritoryField interaction.** Building registration depends on the TerritoryField autoload being present, which requires a SceneTree. Keep the Building unit tests to pure math + isolated field value calculations; integration of registration is covered by the smoke test (the game opens, shader renders, territory updates).

## Deferred from M3 → later

- Camera soft-bound centroid refactor (M1 deferred to M2, now to M4).
- Full dashed-outline ghost shader polish → M7.
- Hover tooltip / label on build pills → M7.

## Done criteria

- [ ] `building.gd`, `building_math.gd`, `tower.gd`, `barracks.gd`, `build_bar.gd`, `build_pill.gd`, `placement_controller.gd`, `ghost_building.gd` exist with colocated `*.test.gd` where pure math lives.
- [ ] `building_placeholder.gd` is DELETED.
- [ ] `main.tscn` uses real `Tower` and `Barracks` nodes; includes `BuildBar` CanvasLayer and `PlacementController` node.
- [ ] `TerritoryField.field_at(Vector2)` exists and is tested.
- [ ] `bash ./run_tests` → green, count has grown by the number of new colocated tests.
- [ ] Headless `--quit-after 120` → exit 0 with no shader/script errors.
- [ ] Visual flow confirmed by the user: click pill → ghost trails cursor → valid/invalid color → place → building registers → cooldown resets.
