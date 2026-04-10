# Tug of War

Cozy minimalist top-down tug-of-war strategy for PC. The player (blue) and an AI opponent (red) fight over a dynamic territory line by spawning units from barracks and defending with towers. Pure black-and-white world with blue/red accents, 3D rounded chunky shapes, thick storybook outlines. Win by destroying every enemy building.

Full design: [`plans/design.md`](plans/design.md).

## Run the game

**Editor (via MCP):**
```
mcp__godot__launch_editor with projectPath = "D:/Games/Godot/Projects/tug_of_war"
```

**Editor (via Bash):**
```
"C:/Users/delmi/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --path "D:/Games/Godot/Projects/tug_of_war"
```

**Headless run (for autonomous debug loop — captures errors via stdout):**
```
"C:/Users/delmi/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:/Games/Godot/Projects/tug_of_war" 2>&1
```
The `_console.exe` variant gives reliable stdout on Windows. Use this whenever you need to read Godot's output without a GUI.

**Quick project import / error check (no scene run):**
```
"C:/Users/delmi/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe" --headless --path "D:/Games/Godot/Projects/tug_of_war" --quit 2>&1
```
Godot imports resources and exits. Any script parse errors or missing-file errors will surface in the output.

## Run tests

From the project root:
```
bash ./run_tests
```
(or just `./run_tests` if your shell honours the shebang)

`run_tests` scans the entire project for files matching `*.test.gd` and runs every `test_*` method in each one, reporting `[PASS]` / `[FAIL]` per method and an exit code of 0 on all-pass, 1 on any failure. No test framework — just a shell script plus a Godot `SceneTree` runner at `tests/test_runner.gd`.

**Tests are colocated** with the code they exercise. For example, `scripts/units/unit.gd` gets a sibling `scripts/units/unit.test.gd`. The only test file outside a colocated pair is the runner itself.

### Writing a test

A test file extends `RefCounted` and exposes one or more methods named `test_*`. Each test returns `true` on pass, `false` on fail. Example — see `tests/sanity.test.gd`.

```gdscript
extends RefCounted

func test_my_thing_works() -> bool:
    var x = 2 + 2
    return x == 4
```

Every new script should ship with a colocated `*.test.gd` exercising at least the happy path.

## Project layout

```
tug_of_war/
├── project.godot          # Godot project config
├── CLAUDE.md              # this file
├── run_tests              # bash script: scan + run *.test.gd
├── plans/                 # design docs and per-feature plans (markdown)
│   └── design.md
├── scenes/                # .tscn files
├── scripts/               # .gd sources; *.test.gd sits next to its subject
└── tests/
    └── test_runner.gd     # SceneTree runner used by run_tests
```

Complex subsystems (e.g. `scripts/territory/`, `scripts/units/`) may get their own `CLAUDE.md` with subsystem-specific guidance when they grow large.

## Workflow rules

1. **Plan first.** Every non-trivial feature begins with a markdown plan in `plans/<feature>.md`. Write it, self-review it for logical inconsistencies, iterate with the user, and only then write code.
2. **Tests alongside features.** Every new script gets a colocated `*.test.gd`. Run `./run_tests` before declaring a feature done.
3. **Headless debug loop.** When something breaks, use the headless run command above to capture errors directly. Don't ask the user to run the game and paste output — do it myself.
4. **Hygiene.** After finishing a feature, re-read the diff, delete unused files and dead code, move things into the right folder. The tree stays tidy.
5. **Update this file.** When any of the commands above changes, or a new subsystem grows a CLAUDE.md, reflect it here.

## Important

*Running list of gotchas. Add to it when a mistake happens twice.*

- **GDScript is not Python.** Do not write `"=" * 50` — that's Python. GDScript equivalent: `"=".repeat(50)`. Generally, don't reflexively autocomplete from Python muscle memory when writing GDScript.
- **Don't shadow GDScript built-ins with variable / parameter names.** `sign` is a built-in math function; naming a var or param `sign` produces `GDScript::reload` warnings. Same rule for `abs`, `min`, `max`, `clamp`, `len`, `range`, `class`, `self`, `type`. Prefer descriptive alternatives like `claim_sign`, `team_sign`.
- **Godot 4.6 syntax.** Use `@onready` and `@export` (not Godot 3's `onready var` / `export`). Signal declarations take typed parameters: `signal health_changed(new_hp: int)`. `yield` is gone — use `await`.
- **Typed arrays.** `var files: Array[String] = []` works; mixing types into it errors at runtime. Prefer typed arrays everywhere.
- **`DirAccess` iteration.** Call `dir.list_dir_begin()` before the loop, `dir.list_dir_end()` after. Skip entries starting with `.` to avoid `.` and `..`.
- **Test files must extend `RefCounted`** (not `Node`) so the runner can `.new()` them cheaply without attaching to the tree.
- **Zone color rings.** A scalar-field shader that uses smooth falloff `(1 - d/r)^2` will produce a visible "ring" just inside the claim radius if you threshold the base color by field magnitude (`F_mag_sum < eps → neutral`). The contribution goes to zero BEFORE `d` actually reaches `r`, so the threshold kicks in early. Determine "inside/outside a claim" via a `smoothstep(r - 1px, r + 1px, d)` test on the raw distance, not via field magnitude. Keeps the zone color constant with a pixel-tight AA edge and no gradient.
- **Isoline false positives.** A territory "line" drawn where `|F|` is small will also appear at the edge of any single claim (because F → 0 as d → r). To restrict the line to the genuine front between two teams, split the sum into `F_pos` and `F_neg` and only draw the line where BOTH are materially above zero.
