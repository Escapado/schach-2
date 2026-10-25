# Upgrade artwork

The screen uses `background.png` as a single scenic image with nearest filtering. `upgrades_mask.png` controls the shared title water shader: white and gray animate water, black preserves the scenery. Both images share the same cover transform. The upgrade scene preserves the painted sunset reflection instead of adding the title's separate cloud reflection. The scenery setting pauses its animation.

The older `clouds.png`, `upgrades_no_clouds.png`, and `panel.png` are retained as source artwork but are no longer composed on screen. Skill trees and headings are positioned relative to the dark stone in the background, with room for node outlines and the detail panel.

UI frames, the four branch headings, connector lines, pixel icons, counters, legend and detail panel are drawn in Godot. The UI uses the supplied `pixelfont.ttf`.

There are 28 visual nodes. Only Deeper pockets, Second look and Bishop's company are implemented. The other nodes are presentation placeholders with no price or unlock transaction.

Hover previews details; clicking pins the selection. The right-hand X clears it. The controller preserves the pinned key across screen rebuilds and uses `GameRun.unlock()` for every purchase, including save failures and rollback.
