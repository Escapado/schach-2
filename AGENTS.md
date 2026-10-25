# Agent guide

## Project intent

Schach / 2 is a chess roguelite prototype in Godot 4.8 beta 1, using GDScript and a simple 2D presentation. Read `README.md` for player controls, formulas, and detailed effect resolution.

The current playable loop is three battles with deployment, objectives, rewards, shops, three next-board choices, and persistent EXP and skills. The design rewards both sacrificing pieces and preserving useful abilities. This is intentionally a chess variant: conventional chess rules are not automatically correct here.

The eventual visual direction is a 3D board with a pixel-art shader. Keep that renderer replaceable. Special pieces, more modifiers, larger runs, and further meta progression are future work, not instructions to implement them during unrelated changes.

## Architecture and ownership

| File | Responsibility |
| --- | --- |
| `project.godot`, `main.tscn` | Engine configuration and application entry scene. |
| `scripts/core/pieces.gd` | Piece types, symbols, values, prices, modifier labels and descriptions. |
| `scripts/core/battle.gd` | Scene-independent battle state, movement, legal actions, resolution, events, objectives, and rewards. |
| `scripts/core/encounters.gd` | Seeded encounter templates, validation, fallbacks, previews, and construction of battle instances. |
| `scripts/core/bot.gd` | Search over private battle copies using the same legal actions as the player. |
| `scripts/core/run.gd` | Owned roster, shop, gold, score, run statistics, EXP, skill unlocks, and profile persistence. |
| `scripts/ui/game.gd` | Screen flow, selection, deployment input, bot thread lifecycle, and settling battle outcomes. |
| `scripts/ui/board_view.gd` | Board drawing, coordinate conversion, highlights, tooltips, and cell-click signals. |
| `scripts/ui/title_screen.gd`, `scripts/ui/pixel_menu_button.gd` | Layered animated title presentation, modal panels, and pixel-framed native buttons. Game controller owns run and profile actions. |
| `scripts/ui/upgrade_screen.gd`, `scripts/ui/skill_node.gd` | Four-tree upgrade presentation, placeholders, hover previews, pinned selection and node drawing. Costs and unlock/save authority remain in GameRun. |
| `scenes/labs/piece_lab.tscn`, `scripts/labs/piece_lab.gd` | Standalone 3D art study, low-resolution viewport, lighting, and preview controls. No simulation or persistence access. |
| `scenes/labs/terrain_lab.tscn`, `scripts/labs/terrain_lab.gd`, `assets/terrain/` | Seeded modular terrain art study with viewport size/zoom controls, reusing the piece lab renderer. `terrain_foliage.gd` and `terrain_leaves.gdshader` adapt reference vegetation with the MIT notice in `assets/terrain/foliage/`. Blender source and rebuild script are `art_sources/terrain.blend` and `tools/build_terrain.py`. No simulation or persistence access. |
| `scenes/labs/terrain_lab2.tscn`, `scripts/labs/terrain_lab2.gd`, `assets/terrain_painted/` | Standalone painted isometric study using anchored source slices and cached transparent 3D piece portraits. `tools/prepare_painted_terrain.py` rebuilds runtime slices. Fixed perspective, seeded connected map, no simulation or persistence access. Dedicated checks in `tests/terrain_lab2_smoke.gd`. |
| `assets/pieces/`, `art_sources/`, `shaders/` | Exported Blender pieces, editable source excluded from Godot import, toon materials and Forward+ depth/normal outlines. |
| `tests/test_runner.gd` | Rules, economy, persistence, determinism, generation, and bounded simulated-game checks. |
| `tests/ui_smoke.gd` | Board input, worker response, screen transitions, purchases, progression, reload, and rendered screenshots. |

Core models extend `RefCounted`. Keep them free of scene-tree access, rendering, animation, and input handling. `GameRun` performs persistence; `Battle` and bot search must remain usable without a scene.

The normal data flow is:

1. `GameRun` owns roster entries and generates encounter choices.
2. The UI records deployment positions keyed by owned roster ID.
3. `Encounters.make_battle()` builds a fresh battle with its own piece IDs.
4. Player input or the bot submits an action to `Battle.apply()`.
5. The UI reads the resulting state and ordered events, then redraws.
6. On a terminal outcome, the UI records the battle once and advances or ends the run.

Owned roster IDs and battle piece IDs are separate namespaces. Do not assume they match. Battle deaths, promotions, damage, and spawned pawns must not mutate the owned roster. Reconstructing the next battle restores owned pieces and clears temporary effects.

## Simulation contracts

- Coordinates are `Vector2i`, with `(0, 0)` at the top left. Side `0` is the player, side `1` the enemy. Player pawns move toward decreasing `y`; enemy pawns move toward increasing `y`.
- Stages are zero-based. Current board sizes are 5×6, 6×6, and 6×7. Deployment is restricted to the bottom two rows, and every owned piece must be placed.
- `legal_actions()` is the action authority. `destinations()` is a movement helper; it does not establish whose turn it is or which phase is active.
- Actions are dictionaries: `{kind: "move", id: int, to: Vector2i}`, `{kind: "reposition", id: int, to: Vector2i}`, or `{kind: "skip"}` for declining a bonus. Keep these compatible across simulation, bot, UI, and tests.
- `apply()` rejects invalid actions without altering the position. Its ordered event dictionaries carry `kind`, `text`, and relevant additional fields. They describe the latest action, not the entire battle history; the UI keeps its own log.
- `copy()` manually lists the state fields to clone. Whenever adding battle state, update that list and verify nested arrays and dictionaries are independent. Copies intentionally omit prior event history.
- Preserve deterministic action ordering and effect resolution. Use local seeded `RandomNumberGenerator` instances for generation, shops, and bot choices. Do not introduce global randomness or clock-dependent simulation behavior.

## Gameplay invariants

These are the current agreed rules. Change them when requested, and update the tests and player-facing descriptions together.

- Objectives decide victory. Kings are capturable, and there is no check, checkmate, castling, en passant, or pawn double-step.
- Ordinary captures kill regardless of HP. Pieces start with 2 HP; poison deals partial damage. Do not convert captures into damage-only attacks accidentally.
- Only ordinary player moves consume the visible move budget. Enemy actions and optional repositions do not.
- Check victory before enforcing the deadline. A final permitted move can win. Check the pawn-reaching objective before replacing the pawn through promotion.
- Promotion uses a queen if the side has no living queen, otherwise a rook. This is battle state and can exceed the purchased rook limit temporarily.
- Losing the player army or having no legal player action loses the encounter. An enemy with no legal action passes. Turn-start poison can itself end a battle, including at `begin()`.
- Reposition follows a capture and permits one optional step to an empty adjacent square. It cannot capture or start a capture chain. Resolve or skip it before ending the turn.
- Death walls remain dormant beneath a capturer, then activate when vacated. Knights can jump over active walls but cannot land on them.
- Reinforcements spawn unmodified temporary pawns in the first free, non-wall home-row square, scanning left to right. A full row means no spawn.
- Poison includes the death square and orthogonal neighbors within bounds. It ticks at each incoming side's turn start for two turns of that side. Overlaps deal at most one damage per piece per boundary.
- Snapshot poison exposure and tick existing clouds before resolving casualties and their effects. Clouds created by those deaths must not tick again at the same boundary.
- Keep owned pawn losses separate from temporary pawn losses. Gold purchases reduce spendable currency, never earned score. Award run EXP once.
- Snapshot unlocked skills at run start. Unlocks affect subsequent runs, not a run already in progress.

## Bot, generation, and UI pitfalls

- Bot evaluation is from the enemy's perspective: higher is better for the enemy. Foresight is now an explicit depth of 1–12 ordinary individual actions, independent of consistency. `choose(battle, depth, seed, options)` accepts `max_nodes`, `beam_width`, and `consistency`; old 0/1 difficulty semantics are removed. The UI exports stage depths `[1, 2, 3]`, node limits `[420, 2400, 6000]`, and consistency `[0.0, 1.0, 1.0]`. Programmatic defaults remain 420 nodes and beam width 10. Iterative deepening keeps only completed root iterations, so budget exhaustion falls back to the last achieved depth. Inspect `completed_depth` and `nodes` when tuning. Bonus actions consume nodes but not depth. Maximize or minimize according to the actual side in each state, including consecutive actions after a pass. Keep horizon, budget-exhaustion, and bonus-turn tests when changing search.
- The bot worker receives a private `Battle.copy()`. Never access controls, nodes, or the live battle from that worker. Apply its returned action on the main thread, and join started threads on shutdown. If adding restart or cancellation during thinking, prevent stale results from reaching a new battle.
- Generated marked targets have front-rank guards to prevent an immediate queen capture from any deployment square. Preserve that regression check when changing formations.
- Encounter validation checks occupancy, required targets, capacity, and opening moves with a standard roster. It does not prove solvability for arbitrary deployments or builds. Keep fallbacks available and assess difficulty through playtesting.
- Purchase capacity is currently hardcoded to 12 because both later boards have six columns. If changing board widths or shop timing, derive capacity from the boards the player can actually choose.
- `_settle()` uses a guard to prevent recording the same battle twice. `GameRun.record_battle()` is not independently idempotent. Keep all outcome paths, including turn-start losses, routed through settlement.
- `show_screen()` rebuilds controls. Do not retain references to buttons or board views across a rebuild. Preserve selection and run state in model/controller fields.
- The menu uses its own full-window title control; other screens use the existing containers. Keep menu seed, open-panel state, and scenery preference in the controller. Keep profile errors and retry accessible on the title screen. Water/cloud animation is cosmetic and must never affect simulation randomness.
- Upgrades is a full-window child of the title control, using the single background and aligned water mask from `assets/upgrades/`. Keep the pinned skill key in `game.menu_skill_selection`; hover state belongs to the view. A pinned selection overrides hover, X clears both, and only a selected, implemented, eligible skill enables Unlock. Refresh the view after unlock without rebuilding it. Placeholder edges do not introduce gameplay prerequisites; the real links remain purse → reroll and purse → bishop.
- Title water effects use the user-painted `assets/title/landscape_mask.png`, with white/gray/black controlling strength. Keep it aligned to the landscape and do not reintroduce color heuristics for the shoreline. Cloud dimensions determine both drawing proportions and reflection UV mapping; the edited tile wraps directly without overlap.
- Wrapping labels in horizontal containers can shrink to single-character columns and inflate the header. Keep header labels non-wrapping and inspect layouts after UI edits.
- Threat hints show legal enemy destinations, not a complete chess attack map. In particular, pawn hints only include currently available captures. Keep their explanation honest if this behavior changes.

## Persistence and repository hygiene

- The player profile is `user://progress.json`, written through a temporary file and rename. Preserve validation, visible save errors, and retry behavior. Consider compatibility when changing the saved EXP or unlock format. Active runs are not saved.
- Tests use dedicated `/tmp` profile files. Never point tests at the player's real profile. The test filenames and screenshot paths are shared, so run these suites sequentially unless first making their paths unique. Adapt temporary paths if adding non-macOS support.
- Keep Godot `.gd.uid` files alongside their scripts. Do not commit `.godot/`, local profiles, logs, or generated QA images.
- Follow the existing GDScript style, including tabs and descriptive names. Prefer focused changes over broad refactors during gameplay work. Keep modifier logic in the simulation, and update the catalog descriptions and bot evaluation where relevant.
- Maintain this guide and `README.md` when changing architecture or agreed behavior. Do not silently replace existing work or commit unrelated files.

## Verification workflow

Run from the repository root using Godot 4.8 beta 1 or the project's explicitly updated engine version. On this machine:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd
```

Use the local Godot executable on another machine. For a fresh checkout, an editor import can populate Godot's script class cache before running standalone scripts:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

Both test runners exit nonzero on failure. Run the rules suite after simulation, AI, generation, economy, or persistence changes. Run the UI suite after controller or screen-flow changes and after changes to the action contract. Add focused cases for new mechanics, especially timing, cloning, and deterministic resolution.

For UI edits, also run the smoke test with rendering enabled and inspect its images:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/ui_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/ui_smoke.gd -- --small
```

Screenshots go to `/tmp/schach2-*.png`. Check both the default 1280×900 window and the minimum 1120×820 window. Headless success alone cannot verify clipping, readability, or rendering.

The UI suite deliberately uses controlled legal formations for its three-battle victory. It also exercises a real background bot response. The rules suite runs unmodified seeded games through termination. Neither is evidence that every generated encounter is winnable or that difficulty is balanced. Report automated checks, visual inspection, and human playtesting separately.

The initial implementation passed 651 rules checks and 40 UI checks. These are historical counts, not counts future changes must preserve. Difficulty and economy still need human playtesting. Do not weaken encounters merely to make the test pilot win, or describe controlled fixtures as a successful generated-run playtest.
