# Models progress

Progress of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Branch `m-models`, worktree `FTGG-models`. Studio place: "FTGG Art" only (Rojo sync on port 34873). Unit defs, `src/client` and `src/server` belong to the other streams; what this stream needs from them is under "Requests" below.

Decisions: `M-1`, `M-2`, ... in [`../decisions/models.md`](../decisions/models.md). Rig and blockout format: [`../contracts/rig.md`](../contracts/rig.md).

## Plan

- **Phase 1:** hand-made blockouts for every T1 unit and structure of both factions (guide 13), one batch at a time, each reviewed from the game camera.
  - [x] Batch 1: T1 ground units. Style rejected in review (M-2); new direction M-6.
  - [ ] Style review: Lancer and Ravager, two variants each under M-6 (section below). **Waiting for your pick.** Then batch 1 is redone in the picked style.
  - [ ] Batch 2: T1 air units
  - [ ] Batch 3: T1 naval units
  - [ ] Batch 4: T1 structures
- **Phase 2** (after the phase 1 silhouettes are approved): low-poly Blender meshes for the key units, exported as FBX, with an import path into Roblox approved first.

## Style review: modern armies (2026-10-21)

The new direction (M-6) is in guide 2.1 and [`../art/style-guide.md`](../art/style-guide.md). Four candidates in `src/shared/Defs/Blockouts/Review/` (M-7), not used by the game yet:

| Variant | Lines | Base | What it has |
|---|---|---|---|
| Lancer A | Leopard 2A6 | grey | arrowhead turret front, five road wheels, panoramic and gunner's sights, bustle |
| Lancer B | Abrams | sand | steep glacis, six road wheels, wide flat slab turret, long bustle with rack, CITV, gunner's sight, remote gun |
| Ravager A | T-90M | olive | reactive-armor tiles on the glacis, skirts and turret brow, six road wheels, slat cage round the turret back, remote gun, sight, fume extractor |
| Ravager B | T-14 Armata | gunmetal | longer hull, seven road wheels, reactive-armor skirt panels, rear slat cage, tall faceted turret, flat protection radars, two sensor boxes, remote gun, active-protection launchers |

All four: long low hull, skirts with road wheels, turret toward the rear, long gun, team color only on skirt stripes, turret side panels and a roof panel (M-8). Same pieces as the def (`base`, `turret`, `barrel`, `muzzle`); each validates against its def.

- **Screenshots** (`debug_out/screens/`, gitignored), each with the current Lancer and Ravager for comparison (order: Lancer current, A, B, Ravager current, A, B):
  - `style_tanks_1_threequarter.jpg`: game camera (55°), three-quarter heading, about 40 studs.
  - `style_tanks_2_profile_camera.jpg`: game camera, units facing screen-left.
  - `style_tanks_3_side_order.jpg`, `style_tanks_4_side_chaos.jpg`: true side views at ground level.
  - `style_tanks_5_silhouette.jpg`: all black, game camera at about 100 studs.
  - In "FTGG Art": folders `StyleReview`, `StyleProfile`, `StyleSilhouette` around x = 300.
- **Budget:** 32–53 parts; estimated 1,350–2,000 triangles as primitives, so the Chaos variants go over 20.1's 1,500 until the phase 2 meshes (style guide 6).

### Needs your review

- Pick one variant per faction (or a mix), and grey or sand for Order, olive or gunmetal for Chaos.
- At 100 studs, the four variants share one tank silhouette (long hull, rear turret, long gun), as the shared rules ask; the factions then differ by base color and secondary shapes (tiles, cages, sensor boxes) more than by outline.
- The muzzles sit at 2.25–2.5 studs; the sim fires from 3.6 (`Combat.MUZZLE_HEIGHT`), so shells would start about 1.2 studs above the barrel. If the low hulls stay, I'll ask the sim session to lower it.
- Batch 1's `84ba52d` is still in the merge queue with the old style for the other 10 units (better than generic blockouts until they're redone). Say if you'd rather hold it.

## Batch 1: T1 ground units (2026-10-21)

Superseded style (M-2); kept until the redo.

Twelve units, six roles, both factions. Lancer and Ravager (from the client stream's C-6) are kept as they were; the other ten are new.

| Role | Order | Chaos | Silhouette cue |
|---|---|---|---|
| Scout | `ord_herald`: low 4-wheeler, sloped nose, glass cab, tiny rear turret | `chs_jackal`: open buggy, roll cage, exposed engine, big rear wheels, shielded gun offset right | smallest, wheeled |
| Light tank | `ord_lancer` (unchanged) | `chs_ravager` (unchanged) | turret and gun |
| Artillery | `ord_verdict`: rear-set sloped turret, 9-stud gun 5 studs past the nose | `chs_hellmouth`: open casemate, fat short tube, recoil spade, loader arm, crates | longest / fattest gun |
| IR SAM | `ord_halo`: 6-wheeler, twin pods on a pedestal around a glass sensor | `chs_hornet`: truck, offset cab, closed rack right, bare missiles left, counterweight | launcher raised on a pedestal |
| Radar | `ord_oracle`: 6-wheeler, shelter, wide flat array tilted back | `chs_watcher`: truck, generator and stack, braced mast, round dish with glowing feed | big panel / dish |
| Worker | `ord_mason`: dozer blade, glass cab, turntable crane with blue emitter | `chs_scrapper`: plow, offset cab, scrap hopper, claw arm with orange glow | arm rising forward |

- **Pieces:** every def piece is in place (`turret`, `barrel`, `launcher`, `dish`, `nano`, `muzzle`); turret pivots on the turret's center, barrel pivots at the trunnion, `dish` and `nano` turn about their mast or turntable. SAM rig: M-3.
- **Muzzles:** 2.4–2.5 studs (scouts), 2.6–3.3 (guns), 3.6–4.3 (SAMs); the sim fires from 3.6.
- **Size:** footprint 1 (about 6 × 8 studs). Heights: 3–4.6 studs; radars and worker arms reach 5.3–7.2 so the role reads from above.
- **Budget (guide 20.1, 300–1,500 triangles per unit):** 12–20 primitive parts per unit. Roblox doesn't report primitive triangle counts; counting a box as 12, a cylinder as about 100 and a ball as about 300, the heaviest (Hornet, 11 cylinders) is about 1,200. The budget mainly constrains the phase 2 meshes.
- **Screenshots** (`debug_out/screens/`, gitignored), game camera pitch 55°:
  - `models_batch1_threequarter.jpg`: team colors, three-quarter heading, about 50 studs.
  - `models_batch1_profile.jpg`: facing screen-left, about 50 studs.
  - `models_batch1_silhouette.jpg`: all black, about 100 studs.
  - In "FTGG Art": folders `BlockoutReview`, `BlockoutProfile`, `BlockoutSilhouette` around x = 100 (M-1).
- **Tests:** `lune run test_client`: 19 specs, 82 passed, 0 failed (`Blockouts.spec` 5 / 5). `lune run test`: 41 specs, 299 passed, 0 failed. `lune run build`: 349 scripts compile, every require resolves.

### Needs your review

- The style split (M-2): Order clean, symmetric and sloped; Chaos heavy, offset, exposed machinery.
- Weakest silhouettes at gameplay distance: Ravager vs Hellmouth (both blocky with a short gun; the Hellmouth's tube is fatter and it has a spade), and the scouts are small enough that their guns vanish.
- Radar and worker arms go above the 3–5 stud guideline of rig.md 3 on purpose.

## Merge queue

- Ready to merge: `84ba52d` (batch 1: T1 ground unit blockouts, both factions; new `docs/decisions/models.md` and `docs/progress/models.md`; touches only `src/shared/Defs/Blockouts/` and those two files).
- Ready to merge: `255dd9f` (new art direction: guide 2.1 and 20.3, `docs/art/style-guide.md`; style-review variants in `Blockouts/Review/`, not used by the game).

## Requests

1. **Sim session (unit defs):** `ord_halo` and `chs_hornet` list a `turret` piece that nothing turns; their weapon turns `launcher` with no pitch. Suggest `turretPiece = "turret", pitchPiece = "launcher"` so the launcher turns on its pedestal and elevates. The blockouts already work either way (M-3). Low priority. Accepted; in the sim session's queue.
