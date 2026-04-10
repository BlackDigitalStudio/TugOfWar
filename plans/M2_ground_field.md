# M2 — The ground field

*Milestone plan. Scope: the playfield ground becomes the territory visualization itself. A custom spatial shader draws a continuous scalar field derived from the positions of "claiming" entities. When an entity moves, the band visibly shifts. No combat, no placement UX, no unit logic — just the signature ground mechanic rendering correctly and updating dynamically.*

## Goals

- The M1 flat gray `PlaneMesh` ground is replaced by a new ground `MeshInstance3D` that carries a custom `ShaderMaterial`.
- A small global singleton (`TerritoryField`, registered as an autoload) holds a registry of active **claim contributors**: any node that has `global_position`, a claim `radius`, and a `team_sign` (+1 player / -1 enemy).
- Each frame, the singleton pushes the current list of claims into the ground `ShaderMaterial` as uniform arrays.
- The shader computes the scalar field **per fragment** via a quadratic-falloff contribution function, and colors the ground:
  - strong positive field → saturated **blue**
  - strong negative field → saturated **red**
  - near zero (the isoline band) → **dark neutral band** (the thick "territory line")
  - far from every claim → **neutral light gray** (the "nothing happens here" outside the warzone)
- The same scalar-field math exists in pure GDScript (`territory_math.gd`) and is covered by colocated tests. The shader is a faithful port of that math, so the tests act as the reference implementation.
- The two placeholder cylinders from M1 now self-register as claim contributors (player → +1, enemy → -1) via a lightweight `building_placeholder.gd` script.
- A debug-only slow orbit on the enemy cylinder lets the user *see* the band flexing when they run the scene. Controlled by an exported flag; easy to disable or remove in M3.
- Headless `--quit-after 120` stays at exit 0 with no errors. Shader compiles on import. `./run_tests` stays green.

## Out of scope for M2

- Unit entities contributing claims (units come in M4; their claim registration lands there).
- Building HP, destruction, rebuilding, placement UI (M3).
- Real Tower / Barracks classes (M3). The `building_placeholder.gd` from M2 is temporary and will be deleted in M3 once real building classes exist.
- Camera changes (still the M1 rig; no tilt, no follow).
- Audio (polish milestone).

## Architecture

```
TerritoryField (autoload, Node)
  ├─ register(claimable)
  ├─ unregister(claimable)
  ├─ sync_to_material(ShaderMaterial)
  └─ all_claims() -> Array   (for tests / debug)

TerritoryMath (RefCounted, pure static helpers)
  ├─ contribution(pos, radius, sign, point) -> float
  ├─ field_at(point, claims) -> float
  └─ Claim inner helper class (plain data)

scenes/main.tscn
  └─ Ground (MeshInstance3D + ShaderMaterial + ground.gdshader)
       └─ on _process: TerritoryField.sync_to_material(self.mesh_material)
  └─ PlayerBarracks (MeshInstance3D + building_placeholder.gd, team=Player)
  └─ EnemyBarracks (MeshInstance3D + building_placeholder.gd, team=Enemy,
                    debug_orbit_speed > 0 for the M2 visual demo)

shaders/ground.gdshader
  ├─ uniform int claim_count
  ├─ uniform vec2 claim_positions[MAX_CLAIMS]
  ├─ uniform float claim_radii[MAX_CLAIMS]
  ├─ uniform float claim_signs[MAX_CLAIMS]
  ├─ uniform vec4 color_blue, color_red, color_band, color_neutral
  ├─ uniform float band_half_width, band_aa
  └─ fragment(): computes field at world XZ, maps to color
```

## Scalar field model

For each claim `c` at world point `p_c` with radius `r_c` and sign `s_c ∈ {+1, -1}`, the contribution at world point `x` is:

```
  d = distance(x, p_c)
  if d >= r_c: contribution = 0
  else: contribution = s_c * (1 - d / r_c)^2
```

The total field is the sum of all contributions:

```
  F(x) = Σ contribution_i(x)
```

Properties:
- Bounded support: each claim only contributes inside its own circle of radius `r`.
- Smooth at the boundary: the quadratic falloff is C¹ at `d = r` (first derivative zero at the edge), so the summed field has no visible ridges where claims end.
- Symmetric under sign flip: swapping teams inverts the sign of the entire field.
- Linear in claim contribution: adding a new claim adds its contribution; convenient for testing.

## Shader color mapping

Given `F = F(x)`:

```
  if |F| < ~0.001 and no claim within radius: neutral light gray
  if F > +band_half_width: blue   (smoothstep in over band_aa)
  if F < -band_half_width: red    (smoothstep in over band_aa)
  otherwise (|F| <= band_half_width): dark band color
```

Smoothstep transitions of width `band_aa` avoid hard aliased edges.

## Tuning defaults (M2)

| Parameter | Default | Notes |
|---|---|---|
| claim radius (placeholder building) | 14.0 | chosen so the two M1 cylinders' territories overlap in the middle. See geometry note below. |
| `MAX_CLAIMS` | 64 | shader uniform array size; plenty of headroom for MVP |
| `band_half_width` | 0.08 | half the width of the dark central band in field units |
| `band_aa` | 0.02 | smoothstep softening on each side |
| `color_blue` | (0.25, 0.42, 0.92, 1) | saturated player color |
| `color_red`  | (0.92, 0.28, 0.28, 1) | saturated enemy color |
| `color_band` | (0.12, 0.12, 0.14, 1) | near-black dark band |
| `color_neutral` | (0.87, 0.87, 0.87, 1) | gray outside all claim circles |
| debug orbit speed (enemy placeholder) | 0.4 rad/s | slow, visible, calming |
| debug orbit radius (enemy placeholder) | 4.0 units | stays inside the claim-influenced area |

**Geometry note.** M1 put the cylinders at `(-8, 0.75, 8)` and `(8, 0.75, -8)`. Straight-line distance is `sqrt(16² + 16²) ≈ 22.6` units. With radius 14 each, the territories overlap over the central `14 + 14 - 22.6 = 5.4` unit stretch, which is exactly where the dark band should sit.

## Steps

1. `scripts/territory/territory_math.gd` — the pure reference implementation.
2. `scripts/territory/territory_math.test.gd` — cover `contribution` + `field_at` happy path and edge cases (at center, at radius boundary, past boundary, two claims canceling at midpoint, sign flip symmetry).
3. `scripts/territory/territory_field.gd` — autoload singleton.
4. `scripts/buildings/building_placeholder.gd` — self-registering on `_enter_tree`, de-registering on `_exit_tree`, optional slow orbit for debug visualization.
5. `shaders/ground.gdshader` — spatial shader, unshaded, per-fragment field computation.
6. Update `scenes/main.tscn`:
   - Replace `StandardMaterial3D_ground` with a `ShaderMaterial` referencing `ground.gdshader`.
   - Attach `building_placeholder.gd` to both cylinder `MeshInstance3D` nodes.
   - Set the enemy cylinder's debug orbit parameters non-zero so movement is visible.
7. Register `TerritoryField` as an autoload in `project.godot`.
8. `bash ./run_tests` → expect `23 + N tests, 0 failures` where N is the new territory_math tests.
9. Headless smoke test: `--quit-after 120` exit 0 with no shader compilation errors.
10. Launch game visually and verify the red territory visibly moves as the enemy orbits; band flexes accordingly.
11. Close plan, update design.md milestones, mark M2 done.

## Self-review (before coding)

- **Are the shader uniform arrays a bottleneck?** At `MAX_CLAIMS = 64` and the inner loop being a single `distance` + two multiplies per claim per fragment, plus the plane being only ~200×200 units at 1080p (maybe 1M fragments), the worst case is ~64M ops/frame. Modern GPUs do this in a fraction of a ms. No bottleneck concern for M2. The approach scales comfortably to M4 (units also claim) and beyond.
- **Does the `(1 - d/r)^2` falloff produce the cozy "surface tension" feel the design calls for?** Quadratic is smoother than linear but sharper than Gaussian at the edge. It matches what the brief describes: the line "curves around clusters and bulges into the attacker." A Gaussian falloff would give a puffier, less confident border; quadratic feels more physical. If the visual disappoints in the M2 review we can switch to a bell curve (`exp(-k*d²/r²)`) without changing the test interface — the tests assert specific numeric values for the quadratic model, so if we change the model we also update the tests in lockstep.
- **How does the shader know the world XZ of each fragment?** The ground plane is a `PlaneMesh` aligned to the XZ plane. In the vertex function, compute `(MODEL_MATRIX * vec4(VERTEX, 1.0)).xz` and pass through a `varying vec2 world_xz` to the fragment. This is the canonical Godot 4 way and doesn't rely on UVs or plane size assumptions.
- **What if two claims with the same sign overlap?** Contributions add, so the field grows stronger there — which means the blue/red zone just looks more saturated in the overlap. That's the intended behavior: a cluster of your buildings has a stronger claim than a lone building. No conflict with the model.
- **What if the shader is called with `claim_count == 0`?** The loop body never runs; `F` stays 0; the `|F| < 0.001` branch triggers and we draw the neutral gray. That's correct behavior for an empty level.
- **Is the autoload ordering safe?** `TerritoryField` must exist before any `building_placeholder` enters the tree, otherwise `_enter_tree` will crash on `TerritoryField.register`. Autoloads are ready before any scene nodes, so this is guaranteed. I'll add a defensive null check anyway (`if Engine.has_singleton(...)` or just `if TerritoryField != null`) as a belt-and-braces safety — the cost is negligible.
- **Test isolation for `TerritoryField`.** It's an autoload, so inside a `*.test.gd` file run via our test runner, it IS already available as a singleton. I'll avoid writing tests that mutate global TerritoryField state — the math tests should target `territory_math.gd` directly, not the singleton. Singleton behavior can be smoke-tested by running the scene.
- **Does the debug orbit contaminate production code?** Yes, if I bake orbit logic into `building_placeholder.gd`. But `building_placeholder.gd` is M2-only scratch that will be deleted in M3, so the contamination is self-disposing. The real `Building` / `Tower` / `Barracks` classes in M3 will not have any orbit logic.
- **M1 → M2 refactor point for soft-bound center.** I said in M1 that soft-bound center would switch from "world origin" to "centroid of nearest friendly entities" in M2+. Reviewing this now: M2 doesn't actually exercise that bound (the player has no reason to pan far during territory-field testing), and the nearest-friendly-centroid is cleaner to implement *after* proper building classes land in M3. I'm deferring that refactor from M2 to M3 and noting it in the M2 "deferred" section below. Small drift from the earlier commitment but makes the dependency chain cleaner.

## Deferred from M2 → M3

- Refactor `CameraRig.apply_soft_bound` to center on the friendly-entity centroid instead of world origin. Needs the real `Building` class to exist. Moved to M3.

## Done criteria

- [x] `scripts/territory/territory_math.gd`, `territory_math.test.gd`, `territory_field.gd`, `scripts/buildings/building_placeholder.gd`, `shaders/ground.gdshader` all exist
- [x] `main.tscn` updated with `ShaderMaterial` on `Ground` and `building_placeholder.gd` on both cylinders
- [x] `TerritoryField` registered as autoload in `project.godot`
- [x] `bash ./run_tests` → all green (43 total: 23 sanity/camera + 15 territory_math + 5 new camera boost tests)
- [x] Headless `--quit-after 120` → exit 0, no shader compile errors, no script errors
- [x] Visual run: enemy cylinder orbits, red territory flexes with it, dark band traces the zero-isoline
- [x] Design doc's milestones section updated to mark M2 "Done"

## Post-visual-review iterations (2026-04-10)

The first draft of the shader passed all automated checks but the user flagged several visual problems during live review. These are documented here as lessons learned:

1. **Saturated zone colors were too loud.** The original palette used fully saturated `vec4(0.25, 0.42, 0.92)` blue and similar red. The user wanted pale tints so the saturated unit/building colors would contrast against the ground. Fixed: pale team tints `(0.82, 0.87, 0.97)` blue and `(0.97, 0.83, 0.83)` red.

2. **Isoline was too thick.** The original `band_half_width = 0.08` was in field units and the resulting line took up a significant fraction of the screen. Fixed: pixel-space distance `dist_px = |F| / fwidth(F)` with a 3-pixel solid core + 1-pixel AA.

3. **Camera mouse-boost was velocity-based and evaporated in ~1s.** The user wanted a persistent boost while the cursor holds an offset in the pan direction. Rewrote as `mouse_boost_factor(mouse_pos, viewport_size, keyboard_dir, max_extra)` taking POSITION and scaling with distance-from-center × alignment. 5 old velocity-based tests removed, 12 new position-based tests added.

4. **Camera was straight-down; units need visible 3D depth.** Tilted camera 30° off straight-down via `Transform3D(1, 0, 0, 0, 0.5, 0.866025, 0, -0.866025, 0.5, 0, 13, 7.5)`. Cylinders now cast visible shadows and have depth.

5. **Aliased geometry edges.** Bumped MSAA from 4x to 8x and added FXAA. Set viewport to 1600x900 for better pixel density.

6. **Mushy, low-res shadows.** Default `soft_shadow_filter_quality = 3` over-softened; default `directional_shadow_max_distance = 100` spread 8192 texels over a huge area. Fixed: filter quality 1, max_distance 25, `shadow_blur = 0.6`. The user also fixed the camera `far` plane which had been clipping shadow casters.

7. **Buildings floating above ground.** When I lifted cylinders to Y=1.0 to avoid shadow acne, they visibly hovered. Returned to Y=0.75 (base exactly on the ground plane); shadow acne wasn't actually an issue with default `shadow_bias`.

8. **False "white contour with gradient" around zones.** The original "neutral outside all claims" detection used `F_magnitude_sum < epsilon`, which triggered ~2% before the actual claim radius because `(1 - d/r)^2 → 0` smoothly. Result was a visible ring of neutral just inside every claim. Fixed: binary `inside_any = max(smoothstep(r - 1px, r + 1px, d))` — hard AA boundary with zero gradient interior.

9. **False dark line at single-claim radii.** The isoline was drawn wherever `|F|` was small, which is true both at the genuine isoline AND just inside any single claim's radius where its own contribution is going to zero. Fixed: split into `F_pos` and `F_neg`, draw the line only where both are materially above zero.

10. **Pixelated tips on the dark line.** Hard `F_pos > eps && F_neg > eps` gate created pixel-edged stop points. Replaced with smooth tip taper: `tip = smoothstep(0, 3px, F_pos/fwidth(F_pos)) * smoothstep(0, 3px, F_neg/fwidth(F_neg))`, so the line fades over ~3 pixels at each tip in addition to the perpendicular AA. Visually rounded caps.

11. **Zoom was stepwise instead of smooth.** Scroll input set `_zoom_level` directly, causing jumps. Split into `_zoom_target` (scroll updates this) and `_zoom_current` (lerps toward target in `_process` at `zoom_smoothing = 12.0`). Continuous zoom feel.

**M2 closed 2026-04-10 after 11 iteration passes.**
