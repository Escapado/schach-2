# Schach / 2

A playable chess roguelite prototype for **Godot 4.8 beta 1**. Open `project.godot` and press **F6 on `main.tscn`**, or **F5** to run the project.

## Play

The title screen has **New Run**, **Upgrades**, **Settings**, and **Exit**. Upgrades opens the permanent skill tree. Settings contains the optional run seed, fullscreen, and a toggle to pause the animated scenery. These display settings last for the current session. Tab and Enter navigate the menu; Escape closes a panel.

The upgrade screen groups skills into Sacrifice, Command, Fortune, and Resilience. Deeper pockets and Second look are in Fortune; Bishop's company is in Command and requires Deeper pockets. The other 25 nodes are marked as future skills and cannot spend EXP. Hover or keyboard focus previews a skill; click to pin its details and enable Unlock when its prerequisites and EXP cost are met. The X clears selection. Back or Escape returns to the title. Gold nodes are affordable, turquoise nodes are unlocked, and gray nodes are locked or future placeholders.

Choose a starting modifier and recipient, then freely arrange your army in the bottom two rows. Click a piece and a highlighted square to move. A gold ring marks a capture objective. Hover pieces to read their modifiers. The optional threat overlay shows enemy legal destinations, including only presently available pawn captures.

Complete the objective within the player move budget. There is no check, checkmate, castling, en passant, or pawn double-step. Kings can be captured. Captures kill immediately; poison deals 1 of a piece's 2 HP. Enemy turns do not consume the player move budget. A bonus reposition is optional, cannot capture, and costs no additional move.

Victories restore the owned army and award score and spendable gold. Shops sell pieces and modifiers. Choose one of three subsequent boards. Finish three battles to win the run. Defeat resets the army and gold; EXP and the three-node skill tree persist. Use the run seed field to replay an encounter/shop sequence. Active runs are not saved.

The initial roster is one of every standard piece. Purchase limits are one king, one queen, two rooks, two bishops, and two knights, with one modifier per piece. The bishop skill raises its limit to three. All owned pieces must fit in the next board's two deployment rows. Battle promotions and temporary reinforcements do not change the owned roster or purchase limits.

## Structure

- `scripts/core/battle.gd`: scene-independent simulation, legal actions, cloning, objectives, ordered events, modifiers, and damage.
- `scripts/core/pieces.gd`: piece symbols, values, prices, and modifier descriptions.
- `scripts/core/encounters.gd`: seeded template variations, validation, fallback formations, and battle construction.
- `scripts/core/bot.gd`: bounded recursive minimax search with configurable depth, including bonus reposition resolution. The UI runs the search on a worker thread using a private state copy.
- `scripts/core/run.gd`: owned roster, purchases, score, EXP, skill limits, and save loading.
- `scripts/ui/`: the 2D board and application screens. Rendering never determines move legality. A future 3D view can consume the same battle state and events.
- `scripts/ui/title_screen.gd` and `pixel_menu_button.gd`: the layered title scene, modal presentation, and native buttons with pixel frames and icons. The controller still owns starting runs, unlocks, seeds, and profile errors.
- `scripts/ui/upgrade_screen.gd` and `skill_node.gd`: the supplied upgrade artwork, four skill trees, hover/pinned selection, pixel icons, requirement details, and unlock feedback. Prices and unlock transactions remain in `GameRun`; the screen only requests purchases through the controller. `assets/upgrades/README.md` describes the background, painted water mask, and artwork-relative tree layout.
- `assets/title/`: landscape, transparent cloud layers, the painted water mask, and artwork notes. The user-edited `clouds-tile.png` wraps directly at its horizontal edges, with no overlap or edge fade. Clouds drift continuously at 8.4 virtual pixels per second with linear sampling; the landscape keeps its nearest-filtered pixel grid. Cloud sizing preserves the source aspect ratio and reflection coordinates follow its actual rectangle. Sky and reflection share `shaders/title_cloud_motion.gdshaderinc`. `landscape_mask.png` matches the landscape dimensions and controls all water effects: white is full strength, black is unchanged, and gray reduces strength. Edit that PNG directly to fix shorelines. `pixelfont.ttf` is the supplied UI font, rendered without antialiasing.

The public simulation accepts dictionaries shaped as `{kind: "move", id: piece_id, to: Vector2i}`, `{kind: "reposition", id: piece_id, to: Vector2i}`, or `{kind: "skip"}` for an optional bonus. `legal_actions()` is the authority, and `apply()` rejects invalid actions without changing the position. `copy()` returns independent nested state. Events contain a `kind`, readable `text`, and relevant IDs, positions, or damage.

## Resolution order

1. Validate the action. Increment the player move count for an ordinary player move.
2. Remove any captured piece, move the attacker, activate vacated walls, then resolve the captured piece's death effect.
3. Check the objective before promotion. When promotion does not win, use a queen if the side has no living queen, otherwise a rook. Promotion can temporarily exceed a purchased rook limit.
4. Check victory and army elimination. Offer any capture-triggered reposition. The bonus must finish or be skipped before advancing the turn.
5. Check the player deadline, after victory checks. The final permitted move can win.
6. Switch sides. Snapshot incoming pieces exposed to poison, decrement the existing clouds' counter for that side, apply one damage per exposed piece, remove casualties, then resolve their death effects in stable piece order. Newly created clouds do not tick at the same boundary.
7. Check the objective and army loss again. No player moves means defeat; an enemy with no moves passes. Clouds expire after two start-of-turn boundaries for each side. Overlaps never stack damage.

A wall remains dormant while its death square is occupied by the capturer, then becomes permanently impassable when vacated. Reinforcements scan the home row left to right for an empty non-wall square. New pawns are unmodified and temporary. Poison crosses include the death square and valid orthogonal neighbors.

## Progression

Victory points: `100 + 5 × remaining player moves + 30 if the bonus is complete`.

EXP at run end: `floor(total earned points / 10) + 10 × battles won + 20 for a full victory`.

Gold purchases do not reduce earned points or EXP. Owned pawn losses and temporary pawn losses are tracked separately. The skill root costs 30 EXP and adds 20 starting gold. Its two 50-EXP branches grant a free reroll per shop or a third bishop slot. Unlocks apply to new runs.

Progress is written atomically to `user://progress.json`. Use Godot's **Project → Open User Data Folder** to find it. Invalid saves fall back to an empty profile with a visible message. Save failures expose a retry button. Tests use separate files in `/tmp` and do not modify the player profile.

## Verification

On macOS with Godot installed in Applications:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd
```

Use your Godot executable instead on another platform. Both runners exit nonzero on failure. The rules runner covers movement, blocking, captures, objectives, modifiers, poison timing, cloning, deterministic generation, shops, limits, persistence, bounded bot searches, and seeded games through termination. The UI runner checks a live background bot response, deployment swaps, controlled three-battle victory, shop purchases, EXP, skill unlocking, reloading a fresh game instance, and defeat.

For rendered QA, run `tests/ui_smoke.gd` without `--headless`. It captures each major screen to `/tmp/schach2-*.png`. Outcome checks deliberately use controlled legal formations, so they remain stable when AI strength or encounter balancing changes.

## Tuning the opponent

Select the `Schach2` root node in `main.tscn` to edit the exported Inspector arrays. Entries correspond to battles one, two, and three:

| Setting | Default | Meaning |
| --- | --- | --- |
| `enemy_depth_by_stage` | `[1, 2, 3]` | Foresight in ordinary individual moves, including both sides. |
| `enemy_nodes_by_stage` | `[420, 2400, 6000]` | Maximum simulated actions for each decision. |
| `enemy_consistency_by_stage` | `[0.0, 1.0, 1.0]` | Probability of choosing the highest-ranked move directly; otherwise pick among the top three. |

Depth 1 evaluates the enemy move; depth 2 includes the player's reply; depth 3 includes the enemy's following move. Repositions are part of the original move and do not consume depth, but their simulations consume the node budget. Consistency 0 can still pick the best move by chance. Priorities remain the weights in `ChessBot.evaluate()` and the piece values in the catalog.

The programmatic API is `choose(battle, depth, seed, options)`. Options support `max_nodes`, `beam_width`, and `consistency`, defaulting to 420, 10, and 1.0. Depth clamps to 1–12. Short stage arrays repeat their final entry; empty arrays use fallback defaults. The old difficulty values 0/1 no longer select different search modes.

Search uses iterative deepening and alpha-beta pruning. At each position, it ranks immediate successors and searches up to `beam_width` candidates. It adopts a deeper result only when the entire retained root set has been evaluated for that iteration. If the budget runs out, it uses the last completed iteration. `completed_depth` reports the achieved horizon; `nodes` reports simulations. With a budget too small to evaluate the initial move set, it returns a legal fallback and reports depth 0. Requested depth is therefore a ceiling, not a promise.

## 3D piece art lab

Open `scenes/labs/piece_lab.tscn` and press **F6** to run the separate visual study. It displays all six Blender-built pieces in ivory and violet, on a small stone board. This scene does not read battle state or player progress.

Use the resolution buttons to compare pixel sizes, toggle outlines, or turn the key light. Hold the left/right arrow keys to orbit and press R to reset the view. The 3D image uses nearest filtering at integer scale; the surrounding controls stay at the window resolution. The shaders require the project's Forward+ renderer because the outlines read the normal and depth buffers.

The faceted models are in `assets/pieces/*.glb`, with ground-level origins and a shared scale. Editable Blender source is in `art_sources/chess_pieces.blend`. That folder is excluded from Godot import so running the project requires no Blender installation. `tools/build_chess_pieces.py` rebuilds the models through Blender's Python API; adjust its output root on another machine. It creates a dedicated scene and leaves other scenes intact.

`shaders/piece_stone.gdshader` supplies toon lighting. `shaders/pixel_outline.gdshader` adapts the reference project's depth and normal edge detection, with its MIT notice in `shaders/REFERENCE_LICENSE.txt`. Pixelation comes from the low-resolution SubViewport, rather than geometry or textures.

For a rendered capture:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/labs/piece_lab.tscn -- --capture
```

This writes `/tmp/schach2-piece-lab.png` and exits. Add `--resolution 1120x820` before the scene path to inspect the minimum window size.

## Current limits

The beam deliberately excludes some legal alternatives from deeper analysis, so this is an approximate search. Encounter validation checks placement, targets, capacity, and opening actions; it is not a proof that every deployment or generated encounter is winnable. Difficulty, prices, and scoring need human playtesting. Standard piece letters remain placeholders in the playable game; the 3D pieces are currently isolated in the art lab. No sound, percentage effects, extra-turn modifiers, general modifier scripting, or active-run resume is included.

## 3D terrain art lab

Open `scenes/labs/terrain_lab.tscn` and press **F6**. This isolated visual study assembles a level 6×6 board, irregular masonry perimeter, varied columns, low ruined walls, a tree, hanging ivy, flowers, and five sample pieces. It reuses the piece lab's orthographic viewport, lighting, pixel scaling, and outline shader. Terrain retains the exported Blender material colors. No battle, movement, or persistence code is involved.

The 24 reusable modules live in `assets/terrain/`; editable source is `art_sources/terrain.blend`. Run `tools/build_terrain.py` through Blender MCP to rebuild only the dedicated SchachTerrain scene and exports. The script currently uses this machine's absolute project path. **New terrain seed** changes paving styles, garden patches, hanging ivy, and foundation variation with a local seeded generator. Arrow keys orbit; R resets the isometric view. The terrain lab defaults to **Fine**, rendering at 1024×576 at both standard window sizes. **Balanced** renders at 512×288 with 2× pixels, and **Chunky** uses 3× pixels. The preview fits the available window; larger requested sizes can be reduced for display. Outline and lighting controls remain available. The piece lab keeps its original resolution controls.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/labs/terrain_lab.tscn -- --capture
```

Capture writes `/tmp/schach2-terrain-lab.png`. Add `--resolution 1120x820` before the scene path for the minimum window, or `--terrain-seed=73` after `--` for another reproducible composition. This is a modular-art proof of concept, not the gameplay board renderer. The kit includes light/dark pairs of weathered, grass-jointed, ivy-covered, and flowered paving, three additional column variants, intact and broken low walls, a branching tree, and meadow, flower, and fern patches. The 6×6 checkerboard remains level; taller decoration stays on the perimeter. The tree and architecture have fixed framing positions while the seed varies the smaller details. More sculpted rock undersides would bring it closer to the concept images.

The terrain study now adapts the MIT-licensed vegetation technique from `references/3DPixelArt_Tutorial_Vegetation/`. Rounded canopy meshes have separate face UVs and normals; the shader expands each masked leaf patch toward the camera, uses five-step diffuse and rim lighting, and adds subtle noise-driven wind. A separate opaque canopy proxy casts shadows, matching the reference's setup. Hanging ivy uses the same shader with smaller patches. Unlike the reference's implicit vertex offsets, this adaptation stores face centers explicitly to keep billboard expansion stable across tree and vine orientations. The source leaf mask and MIT notice are in `assets/terrain/foliage/`; the adapted shader is `shaders/terrain_leaves.gdshader`. `scripts/labs/terrain_foliage.gd` constructs the meshes. The exported Blender tree supplies the trunk; its earlier textured canopy is replaced in the lab. Existing Blender exports and rebuild scripts remain usable.

The **Viewport width × height** fields resize the preview independently, including its aspect ratio, and **Camera zoom** changes framing. Fine uses the entered dimensions; Balanced and Chunky divide render dimensions by two and three, respectively. Large previews fit down to the available window area; the footer reports actual render dimensions and display scale. `--viewport=800x600` selects a preview size for captures, `--pixel-scale=1`, `2`, or `3` selects detail, and `--orbit-degrees=80` captures another camera angle.

## Painted terrain lab

Open `scenes/labs/terrain_lab2.tscn` and press **F6** for the separate painted-art experiment. It uses the supplied slices in `art_sources/slices/sliced/`, with a continuous isometric floor, hanging stone foundations, garden ledges, columns and a ruined arch. Ivory and dark pieces are the existing Blender models, rendered live in transparent 64×96 viewports with fixed palette shading. The painted camera angle stays fixed. This scene does not access gameplay or player progress, and the original terrain lab remains available.

**New map** or **N** increments the seed. **Broken paths** cuts a few connected gaps and corners; turn it off for a complete 6×6 board. Garden ledges and foundations still vary. **G** toggles grid edges, **P** toggles pieces, and **Piece outlines** toggles their one-pixel silhouette. Click a tile to mark its shared ground anchor. The full composition renders at 600×380 with nearest filtering and fits both window sizes.

Alignment uses a lattice rather than each image's bounding box. Cell `(x, y)` maps to `origin + (30 × (x − y), 17 × (x + y))`. Floor diamonds share exact vertices and sample only the painted top of slice 09, avoiding internal vertical slab seams. Cliffs use measured top-face anchors, while architecture uses ground-contact anchors. Pieces use their 3D camera's projected model origin as the same ground anchor. Ground-contact positions also determine foreground sorting, so a column can cover a piece behind it. The camera elevation follows `sin(elevation) = 17 / 30`. Random generation operates on occupied grid cells, preserves all sample piece locations, and rejects removals that disconnect the island. It never rotates painted sprites to fake another perspective.

Godot ignores `art_sources/`. `tools/prepare_painted_terrain.py` copies the main connected alpha component of selected slices into `assets/terrain_painted/`, removing detached fragments from neighboring slices while preserving dimensions. Rebuild with Python and Pillow if the source art changes. `assets/terrain_painted/README.md` documents the anchors and extension rules. Palette shading, silhouette edges and the simple mist background live in the three `painted_*.gdshader` shaders. The mist and distant silhouettes are a framing study; they do not reproduce the reference's detailed forest, waterfalls or sky.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/terrain_lab2_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/labs/terrain_lab2.tscn -- --capture
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1120x820 scenes/labs/terrain_lab2.tscn -- --capture --terrain-seed=73
```

Capture writes `/tmp/schach2-terrain-lab2.png` and the artwork alone to `/tmp/schach2-terrain-lab2-art.png`. Add `--intact` or `--no-pieces` after `--` to inspect those variants. The dedicated smoke test checks repeated seed output, connectivity across 120 seeds, preserved piece locations, projection round trips, exact shared floor vertices, piece origins, cached view reuse and control state. This verifies the art lab's construction, not gameplay balance or generated encounter solvability.
