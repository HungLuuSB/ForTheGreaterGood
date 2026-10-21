# Models progress

Progress of the models stream: hand-made blockouts in `src/shared/Defs/Blockouts/<id>.luau` and everything under `assets/models/`. Branch `m-models`, worktree `FTGG-models`. Studio place: "FTGG Art" only (Rojo sync on port 34873). Unit defs, `src/client` and `src/server` belong to the other streams; what this stream needs from them is under "Requests" below.

Decisions: `M-1`, `M-2`, ... in [`../decisions/models.md`](../decisions/models.md). Rig and blockout format: [`../contracts/rig.md`](../contracts/rig.md).

## Plan

- **Phase 1:** hand-made blockouts for every T1 unit and structure of both factions (guide 13), one batch at a time, each reviewed from the game camera.
  - [x] Batch 1: T1 ground units (this section). **Waiting for style review.**
  - [ ] Batch 2: T1 air units
  - [ ] Batch 3: T1 naval units
  - [ ] Batch 4: T1 structures
- **Phase 2** (after the phase 1 silhouettes are approved): low-poly Blender meshes for the key units, exported as FBX, with an import path into Roblox approved first.

## Batch 1: T1 ground units (2026-10-21)

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

## Requests

1. **Sim session (unit defs):** `ord_halo` and `chs_hornet` list a `turret` piece that nothing turns; their weapon turns `launcher` with no pitch. Suggest `turretPiece = "turret", pitchPiece = "launcher"` so the launcher turns on its pedestal and elevates. The blockouts already work either way (M-3). Low priority.
