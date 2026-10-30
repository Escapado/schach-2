# Chaos sandbox: prototype rule decisions

Open `scenes/sandbox/chess_sandbox.tscn` and press F6. The default 8×8 position plays ordinary chess. Experimental builds retain **check and checkmate for ordinary kings**. King moves and other actions must preserve king safety; a king cannot be captured directly. No legal escape while checked is checkmate, and no legal move without check is stalemate. Twin Regents instead require both royal pieces to be captured. Variant castling/en passant and automatic repetition/fifty-move draws remain disabled. Pawns retain double steps and promote automatically to queens. A royal keeps its identity if Backup changes its movement type. The original roguelite's objective rules are separate.

The free debug shop has Pieces, Units, and Board tabs. Hover an entry for its rule. Pawn types and positions are fixed during manual preparation; unit upgrades remain allowed. Editing, rearranging or upgrading a paired piece changes its mirrored partner too. The standard king/queen center is the unique-piece exception. Paired pieces stay in mirrored slots in the bottom two rows; terrain editing covers the bottom half. The 10×10 expansion preserves these mirrored slots. Removal remains disabled. Unit items apply to a clicked friendly piece and its same-type mirrored partner, including pawn upgrades. Board switches apply immediately. Walls/mines toggle on empty tiles; erase clears terrain. The Conveyor Belt board upgrade toggles one fixed clockwise roundabout across the two empty ranks immediately in front of your army (ranks 3 and 4). It spans the full board width and resizes on 10×10. There is no route painting; the terrain eraser cannot cut the loop. Reset clears the experimental build.

After a battle, **Next battle** restores the saved starting army, equipment and player terrain, then opens preparation against an increasingly upgraded enemy. Temporary deaths, Gun use, Backup use, spawned pieces, and holes do not carry over. Starting layouts last for this scene session; there are no profile writes or gold/reward economy. Opponent families cycle Shooting Club, Night Shift, Moving Company; +1 enters from battle 4 and +2/Guns from battle 7. This is an editable test progression, not a balanced run generator.

## Implemented accepted content

- New pieces: paired Portals, Ghost, Elephant, Bouncer, Seductress, Factory.
- Unit upgrades: Phasing, +1, +2, concealed Assassin Dagger, single-use Gun, Recoil, Voidwalker, Eldritch, Backup.
- Army/board: Twin Regents, 10×10, horizontal wrap, Brittle Board, fixed conveyor roundabout, walls, buried mines.

Neural/MCTS search, a complete economy, and balance/solvability guarantees remain architectural proposals.

## Provisional movement and resolution

- Hunter has been removed from the catalog, enemy formations and assets. Gun shoots in any of eight directions and is consumed on use. Shooting takes one action; first ally blocks the shot. Walls and missing tiles stop movement and shots. Knights jump over walls but cannot land on them.
- Phasing applies to sliding movement and permits crossing pieces, not ending on allies. Ghost crosses pieces, captures only royals (including Regents), and cannot land on another occupied square. Elephant can move one or two orthogonal squares and captures both enemies along its path; allies block it.
- Portals are immobile units, exactly a pair per side. A friendly slider entering one continues in the same direction from the other, using the pair at most once per ray. Portals can be captured by enemies. Portal transport does not itself count as a separate move. Non-sliders do not travel through portals.
- Bouncer remains in place when pushing a friendly or enemy neighbor, which stops before the next obstruction or board edge. It cannot push into a hole or off the board. A blocked push spends the action. Seductress has king movement and converts adjacent enemies in place; royals are immune, gear follows the converted piece, and the converted piece cannot take over an ongoing bonus sequence.
- Regents move as queens with a range of three; both must be captured.
- +1/+2 apply to one acting piece for the current turn. They replace one another, never stack, and allow two/three mixed moves or attacks. The rest of the army cannot act during the bonus sequence. Finish early with **End bonus turn**. The debug shop exposes late upgrades immediately for testing.
- One-use Backup becomes a rook, preserves allegiance/remaining gear/royal identity, and cancels the whole attacking action. No Dagger triggers for a cancelled capture. Earlier captures/effects in a multi-capture roll back too.
- Otherwise remove the captured unit, then apply Dagger retaliation. Shot deaths use the same capture resolver as moves.
- After surviving captures, displace the attacker; apply Eldritch departure removal, then the arrival mine. Recoil returns a surviving capturer only if its departure still exists and is empty. The return is another displacement and can trigger Eldritch/mines. A non-Voidwalker that lands off-board after capturing dies.
- At a completed turn: advance all conveyors, collapse one Brittle tile, switch side, spawn Factory pawns, check victory/mobility. Capture victory is checked before end-turn terrain. Conveyors advance simultaneously by one tile, never capture, and blocked units stay. Filled closed loops rotate. Walls, holes or an obstructing unit can block the roundabout; it never reroutes. Each moved unit advances once, and arrival mines/holes and Eldritch resolve deterministically after the simultaneous displacement. Movement is recorded in the log. Factory spawns at owner-turn start (including the first), forward one square, on an intact empty tile. Its unmodified temporary pawn can act that turn.
- Every displacement triggers Eldritch, including pushes and belts. Missing tiles are impassable; removed squares do not count as Voidwalker space. Mine ownership persists; only enemies trigger it, once, upon arrival. Collapse picks the outermost remaining layer, top to bottom then left to right, and destroys an occupant directly. Ordinary kings use checkmate or stalemate at turn boundaries, after incoming Factory spawns; custom royals with no legal action lose. Bonus moves do not prematurely hand victory to an opponent still waiting for its turn. No automatic repetition or fifty-move draws run in variant mode.

## Infinite space and interaction controls

Equipping Voidwalker reveals purple void cells around the board. Select the piece and click an off-board cell to move normally; off-board pieces remain drawn and clickable. Use the mouse wheel or +/− to zoom, right-drag or arrows to pan, and Home to return to the board. Clicking after panning validates direct movement even beyond the finite highlighted candidate window. The camera follows a selected piece after distant movement. Coordinate x,y / Go entry remains available for precise large moves (top-left is `0,0`), and the off-board selector can focus distant units.

Ordinary sliders can target aligned off-board enemies through empty void, even at very large distances, and die there unless they too have Voidwalker. An off-board Voidwalker can also capture an aligned enemy on the finite board at arbitrary distance. Walls, holes, and intervening pieces still block as normal. Horizontal wrap takes precedence over horizontal void: x stays within board files, but y can extend infinitely. Coordinate entry validates arbitrary-distance sliding geometry using occupied/terrain coordinates, not a distance-sized loop.

AI and clickable highlights enumerate a finite nearby window (at most 256 ray steps), plus validated occupied targets when either attacker or target is off-board. They cannot exhaustively search infinitely many empty destinations. Portal travel uses the on-board highlights; coordinate entry validates direct geometry. Use **Ranged attack** to choose shooting rather than moving to the target, including through the coordinate fields.

## Hidden information and search

King-safety probes account for turn-end terrain but omit concealed enemy Daggers/mines. Hidden traps can therefore kill a king after an otherwise legal action. If Backup cancels a check evasion and leaves the king checked, the same player retains the opportunity to resolve check.

The existing bounded search runs on the same deterministic simulator, with variant values for royals, equipment and extra actions. Worker copies omit opposing Daggers and enemy mines. Search remains approximate and node-limited; human playtesting is needed to assess strength.

## Architecture and checks

Focused regressions for check/mate and Factory pawns are in `tests/chaos_fixes.gd`; run it alongside the suites below.

`tests/chaos_setup_void_belts.gd` drives real mouse clicks through the scene and verifies fixed pawns, mirrored edits, void movement/camera and fixed roundabout geometry, resizing and movement; run at both window sizes. `chess_board_view.gd` extends the BoardView data/input contract with a local camera renderer that includes the surrounding void.

`chaos_catalog.gd` contains descriptions/values. `chaos_battle.gd` subclasses the orthodox `chess_battle.gd`, owns all variant state and transitions, and deep-copies every field into concrete variant instances. The UI owns only controls, build snapshots and worker lifecycle. Shared main-game files and persistence remain independent.

Run sequentially from the root, adding `--log-file /tmp/<unique-name>.log` if needed:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chess_sandbox_rules.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chess_sandbox_ui.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chaos_setup_void_belts.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chaos_sandbox_rules.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chaos_sandbox_ui.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/chaos_sandbox_ui.gd -- --small
```

Rule fixtures cover every accepted mechanic, cancellation, cloning, hidden-information filtering, bounded AI, and deterministic mixed-rule replay. UI checks cover the three shop tabs, terrain painting, variant actions, next-battle restoration, both sizes, and a real background bot response. They establish contracts, not balance or rendered visual quality. Run rendered UI checks and manually play combinations in Godot.
