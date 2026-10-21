# Models decisions (M-)

Decisions of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Progress is in [`../progress/models.md`](../progress/models.md). The blockout format and the rig are the client stream's contract ([`../contracts/rig.md`](../contracts/rig.md), decisions C-4, C-6, C-8); this stream follows it and doesn't change it.

Each entry gives the date, the decision, the alternatives and the reason. Overrule any of them and the blockouts, the guide and this file are updated together.

## Summary

| ID | Decision |
|---|---|
| M-1 | Blockouts are reviewed in the "FTGG Art" place as three lineups built from the synced data (team colors, profile, black silhouettes) at the game camera's 55° pitch |
| M-2 | Faction shape language for blockouts: Order symmetric and sloped with glass; Chaos flat-faced, heavy, offset, with exposed machinery and orange glow |
| M-3 | IR SAMs: `turret` is a fixed pedestal, `launcher` turns on the pedestal's axis; pods level at rest |
| M-4 | Artillery reads by its gun, not its elevation: barrels are level at rest like every other unit |
| M-5 | A wedge's slope faces forward (−Z) unrotated: glacis, noses and turret fronts take no `rot` |

### M-1 — Review in "FTGG Art" (2026-10-21)

**Decision:** each batch is built in the "FTGG Art" place from the Rojo-synced blockout modules with the client's own `BlockoutBuilder`, into three workspace folders: `BlockoutReview` (team colors, three-quarter heading), `BlockoutProfile` (facing screen-left) and `BlockoutSilhouette` (all black). Order on the near row, Chaos behind, one column per role, 18 studs apart. Screenshots use the game camera's pitch (55°, `src/client/Camera.luau`) from the south, at review distance (about 50 studs) and gameplay distance (about 100 studs). The folders are place content for review only; the modules in the repo are the source.

**Alternatives:** headless renders (`lune run render_scene`, top-down only); building models by hand in the place (not reproducible).

**Why:** the same builder the game uses, the game's camera angle, and a silhouette pass for guide 20.1's "silhouette first".

### M-2 — Faction shape language (2026-10-21)

**Decision:**

- **Order:** symmetric; sloped wedges for glacis, noses and turret fronts; glass cabs, optics and array faces in blue glass; long, thin guns; six small wheels on carriers. Team color on the turret or the top-facing piece.
- **Chaos:** flat-faced heavy boxes; rams and plows in front; a skirt on one side only; cabs, weapons and masts off-center; exposed engines, generators, crates, pistons and stacks; orange glass in slits and glow points; big wheels, fat short guns. Team color on the turret, rack, arm or dish.

Both factions share each role's key silhouette cue, so a role reads the same either side: scout = smallest, wheeled, tiny gun; light tank = turret and gun; artillery = longest or fattest gun; IR SAM = launcher raised on a pedestal; radar = big panel or dish above the hull; worker = crane or claw arm rising forward.

**Alternatives:** palette-only difference (C-6's palettes alone).

**Why:** guide 2.1 and 20.3 ("clean slopes vs heavy blocks") so the factions read apart even at low detail, and guide 20.1's silhouette rule.

### M-3 — IR SAM rig (2026-10-21)

**Decision:** `ord_halo` and `chs_hornet` list the pieces `turret` and `launcher`, but their weapon turns `launcher` (`turretPiece = "launcher"`, no `pitchPiece`). The blockouts make `turret` a fixed pedestal on the hull and `launcher` (pods, sensor, missiles) a child of it, pivoting on the pedestal's vertical axis. The pods are level at rest (rig.md 2). If the defs later turn `turret` and pitch `launcher` (request 1 in the progress file), the same blockouts work: the launcher's pivot is on the pedestal's axis at trunnion height.

**Alternatives:** `launcher` under `base` and `turret` as a decoration-like piece; pods modeled pre-elevated (would add a fixed offset to any future pitch).

**Why:** works with today's defs and with the rig a SAM would normally have, with no change to either.

### M-4 — Artillery at rest (2026-10-21)

**Decision:** Verdict and Hellmouth have level barrels at rest, like every pitch piece (rig.md 2: `Transform = identity` is the rest pose). Verdict reads by a 9-stud gun reaching 5 studs past the nose; Hellmouth by a fat 1.3-stud tube with a breech ring and a lip, a recoil spade and ammo crates.

**Alternatives:** model the tube elevated inside the piece (breaks the rest-pose rule and the server's pitch).

**Why:** the client's piece script pitches the barrel from the server's aim; a built-in offset would show the wrong angle.

### M-5 — Wedge orientation (2026-10-21)

**Decision:** an unrotated wedge's slope faces forward (−Z) and up, its tall face at the back; checked in a Studio side view (Verdict's glacis and turret front). Glacis plates, noses, windshields and turret fronts use no `rot`.

**Why:** settles the convention for every later blockout. Note: `chs_juggernaut`'s glacis has `rot = { 0, 180, 0 }`, which turns its tall face forward; to check in the T2 batch.
