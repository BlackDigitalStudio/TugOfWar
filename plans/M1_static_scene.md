# M1 — Static scene and camera rig

*Milestone plan. Scope: get a `main.tscn` on disk that opens headlessly without errors, with an orthographic top-down camera rig that the player can drive around with WASD, zoom with the scroll wheel, and feel the soft bounds when panning into empty space. No gameplay yet — just placeholders.*

## Goals

- `main.tscn` exists, is set as `run/main_scene` in `project.godot`, and Godot imports it headlessly with exit code 0 and no errors.
- Player can pan the camera using **WASD** or arrow keys.
- If the mouse is moving in the same direction as the keyboard pan (within ~60° cone), the camera speed is boosted ~1.5×.
- Mouse alone does NOT move the camera.
- Scroll wheel zooms orthographic size within **0.7× – 1.5×**, step 0.1×.
- Panning into "empty space" produces a **soft cozy deceleration** (proxy: distance from world origin; later milestones will switch to distance from the nearest friendly entity).
- Placeholder rounded-cylinder buildings sit at bottom-left (player, desaturated blue) and top-right (enemy, desaturated red) of the starting view.
- Placeholder flat gray ground (real dynamic territory field lands in M2 — not here).
- `scripts/camera/camera_math.gd` — pure static helpers for direction reading, mouse-boost detection, zoom clamping, and soft-bound drag.
- `scripts/camera/camera_rig.gd` — `Node3D` that composes the static helpers into per-frame motion.
- `scripts/camera/camera_math.test.gd` — colocated tests for every public static function in `camera_math.gd`.
- `./run_tests` stays green.

## Out of scope for M1

- Clicking on buildings, building selection, focus targeting (M5).
- Units, spawning, combat (M4).
- Territory field shader (M2).
- Enemy AI (M6).
- Win/lose (M7).
- Music and SFX (come with M7 polish pass; can land earlier if free time).

## Design choices for this milestone

- **Camera tilt.** For M1 I'm using a straight-down orthographic look (camera at local offset `(0, 15, 0)` looking `-Y`). The slight "storybook tilt" comes later in M7 polish — straight-down is the simpler default and avoids transform-matrix math in the first scene file.
- **Soft-bound proxy.** M1 has no entities to reference, so soft-bound uses `CameraRig.position.length()` — the distance from world origin — as the "distance from activity" proxy. M2+ will replace that with distance from the closest friendly entity (or centroid). This is an explicit M1→M2 refactor point.
- **Ground placeholder.** `PlaneMesh` 200×200, flat gray. Deliberately visible-only-where-the-camera-is; the ground is 200 units wide, more than the soft-bound radius, so the player will see "gray plane → drag stops" without the plane ending abruptly.
- **Building placeholders.** `CylinderMesh` (`top_radius = bottom_radius = 0.8`, `height = 1.5`). Player one sits at `(-8, 0.75, 8)` (bottom-left in the straight-down camera view, because W → `-z`, so the player base at `+z` is "down" on screen and `-x` is "left"). Enemy sits at `(8, 0.75, -8)` (top-right).
- **Lighting.** Single `DirectionalLight3D` tilted slightly, enough for the cylinders to cast visible shadows so the scene isn't entirely flat.
- **Light levels.** Placeholder gray is `Color(0.78, 0.78, 0.78)`. Placeholder team colors for M1 only (will be replaced with the proper saturated-color + outline look in M7): player `Color(0.35, 0.50, 0.90)`, enemy `Color(0.90, 0.35, 0.35)`.

## Tuning defaults (edit in inspector later)

| Parameter | Default | Notes |
|---|---|---|
| `pan_speed` | 8.0 | world units per second at 1× zoom |
| `boost_multiplier` | 1.5 | mouse-in-same-direction boost |
| `boost_cone_cos` | 0.5 | `cos(60°)` |
| `boost_min_mouse_px_per_sec` | 80.0 | ignore sub-threshold mouse jiggle |
| `zoom_min` | 0.7 | smallest ortho size multiplier |
| `zoom_max` | 1.5 | largest ortho size multiplier |
| `zoom_step` | 0.1 | per scroll notch |
| `zoom_default` | 1.0 | start zoom |
| `base_ortho_size` | 12.0 | Camera3D.size at 1× zoom |
| `pan_smoothing` | 10.0 | higher = snappier lerp to target velocity |
| `soft_bound_radius` | 30.0 | distance where drag begins |
| `soft_bound_falloff` | 10.0 | distance over which drag ramps from 0 to 1 |

## Steps

1. Write `scripts/camera/camera_math.gd` — pure static helpers, no state.
2. Write `scripts/camera/camera_math.test.gd` — colocated tests.
3. Write `scripts/camera/camera_rig.gd` — `Node3D` script composing the helpers.
4. Write `scenes/main.tscn` — hand-authored scene with ground, lights, camera rig, two placeholder buildings.
5. Update `project.godot` to set `run/main_scene = "res://scenes/main.tscn"`.
6. `bash ./run_tests` → 3 sanity + camera_math tests all pass.
7. Headless import smoke test:  
   `"<godot_console.exe>" --headless --path . --quit 2>&1` → exit 0, no parse errors.
8. Update CLAUDE.md workflow rules only if something concrete changes (expect nothing).
9. Close this plan: check the boxes below and commit the list into the main design doc's Milestones section.

## Self-review (logical inconsistencies to check before coding)

- **Straight-down camera vs. "slight tilt" art direction.** The design doc says "slight tilt for depth." M1 ships with straight-down; this is a deliberate deferral to avoid transform math in the first scene. Note the deferral in the file and pick up in M7 polish. ✓ acknowledged, no conflict.
- **Soft-bound proxy mismatch.** M1 uses distance-from-origin; the real behavior is distance-from-activity. I've listed this as an explicit refactor point for M2. ✓ acknowledged.
- **Input fallback for keyboard.** I'm reading both `ui_up/down/left/right` (Godot's default action names) AND raw WASD key codes. That means if the project's InputMap has the default UI actions bound to arrow keys (it does), the player gets both arrow keys and WASD for free without me having to edit the InputMap in M1. ✓
- **Test isolation.** The camera rig's `_process` is hard to test without a scene tree. I've factored all logic into pure static functions in `camera_math.gd`. The tests cover those functions; `camera_rig.gd` is a thin composition layer that calls the helpers. This keeps tests fast and framework-free. ✓
- **Mouse velocity direction in the boost check.** Screen coordinates have Y pointing DOWN, but my keyboard Z direction is world-space Z (and the straight-down camera projects world X/Z to screen X/Y without flipping). I need to verify this mapping in the math helper: does a W press (keyboard_dir = `(0, 0, -1)`) correspond to a mouse velocity of `(0, -1)` in screen space (pixel Y decreasing, i.e. mouse moving UP the screen)? — **Yes.** When the camera looks straight down along -Y, world +X → screen +X (right), world -Z → screen -Y (up). So the math helper needs to receive a 2D keyboard direction `(kb.x, kb.z)` and a 2D mouse velocity in screen pixels with the SAME sign convention. In that mapping the dot product is meaningful directly. ✓ will encode this explicitly in `camera_math.is_mouse_boosting`.

## Done criteria

- [x] All files listed above exist on disk
- [x] `bash ./run_tests` prints `23 tests, 0 failures` (3 sanity + 20 camera_math)
- [x] Headless `--quit-after 120` returns exit 0 with no error messages
- [x] `run/main_scene` points to `res://scenes/main.tscn`
- [x] Design doc's Milestones section updated to mark M1 "Done"

**M1 closed 2026-04-10.**
