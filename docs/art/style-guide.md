# Art style guide

How units and structures look. Source: design guide 2.1 (faction look) and 20 (art pipeline); decisions `M-` in [`../decisions/models.md`](../decisions/models.md). The rig (axes, piece names, joints) is in [`../contracts/rig.md`](../contracts/rig.md) and doesn't change with the style.

**Status (2026-10-21):** direction set (M-6). Two Lancer and two Ravager variants are in review (`src/shared/Defs/Blockouts/Review/`); the palette and the variant per faction get picked from them, then this guide is finalized and the rest of the roster follows it.

## 1. Direction

Modern armies, not science fiction or post-apocalypse. Each faction takes after one real-world family of equipment, simplified into a low-poly, flat-shaded "tabletop military" look (guide 20.1).

| | **Order** | **Chaos** |
|---|---|---|
| Inspired by | Western armies: Leopard 2, Abrams, Patriot | Eastern armies: T-90M, T-14 Armata, Pantsir |
| Base color | Light grey or sand | Dark olive or gunmetal |
| Armor | Clean, angular wedge armor; flat faces | Heavier and blockier; reactive-armor tiles and slat cages |
| Sensors | Flat-panel sensors, neat sight boxes | Sight boxes, protection radars, more of them |
| Weapons | One main weapon, a small remote gun at most | More weapons per vehicle: remote guns, launchers, active protection |

## 2. Shared rules (both factions)

- **Hulls:** long, low and wide. Glacis wedge in front, flat engine deck at the back.
- **Running gear:** side skirts with road wheels showing below them, and a track belt on the ground.
- **Turrets:** flat, set toward the rear of the hull. Bustle or slat cage behind.
- **Guns:** long. A tank's gun reaches well past the nose.
- **Sights and sensors:** small boxes on the roof with a dark glass face.
- **SAMs:** canister launchers (boxes or tube bundles), never bare missiles on rails.
- **Radars:** flat phased-array panels, never dishes.
- **Team color:** only on panels and stripes: a stripe on each skirt, a panel on each turret side and a roof panel (like an air-recognition panel) so the team reads from the RTS camera above. Never a whole turret or hull.
- **Glass:** dark tinted, never glowing.
- **Never:** exposed engines, smoke stacks, crates, pistons, rust, round dishes, glowing orange, bright saturated hulls, toy proportions (big turret on a short hull).

## 3. Detail order

Build in this order and stop when the budget is spent:

1. **Silhouette:** hull, turret, gun, skirts. Must read as a black shape from the game camera (55° pitch) at about 100 studs.
2. **Secondary shapes:** bustle, sight boxes, remote gun, reactive-armor rows, slat cage, launcher boxes.
3. **Small details, only if cheap:** glass faces, team stripes, deck plates.

## 4. Palettes (candidates)

RGB 0..255, by blockout palette key (`hull`, `dark`, `track`, `metal`, `glass`; `team` comes from the player's team color). Data: `src/shared/Defs/Blockouts/Review/Variants.luau`. One per faction gets picked; it then replaces `Blockout.PALETTES`.

| Key | Order grey | Order sand | Chaos olive | Chaos gunmetal |
|---|---|---|---|---|
| hull | 166, 170, 162 | 186, 170, 132 | 80, 86, 60 | 76, 80, 84 |
| dark | 92, 96, 92 | 110, 100, 80 | 50, 54, 40 | 46, 48, 52 |
| track | 44, 45, 43 | 48, 46, 42 | 36, 36, 32 | 34, 34, 34 |
| metal | 120, 124, 118 | 138, 130, 110 | 90, 94, 82 | 98, 102, 106 |
| glass | 34, 48, 60 | 36, 46, 52 | 40, 52, 48 | 44, 58, 62 |

## 5. Proportions (footprint 1 ground units)

- Hull 5.8 studs wide (skirts to 6.3), 7.4–7.8 long plus a 1.0–1.2 glacis; hull top at 1.8–1.9.
- Turret top at 2.6–3.0; the tallest roof detail at 3.3.
- Gun 6.0–6.4 studs, from the turret front; muzzle at 2.25–2.5 studs high.
- Road wheels 0.95–1.1 studs across, 5–7 per side.

## 6. Budget

Guide 20.1: 300–1,500 triangles per unit. The variants are 32–53 primitive parts (11–16 cylinders, mostly road wheels) against 13 for the current Lancer and Ravager. Roblox doesn't report primitive triangle counts; at about 100 per cylinder and 12 per box they come to roughly 1,350 (Lancer A) to 2,000 (both Ravagers), so the Chaos variants go over budget as primitives. The phase 2 meshes merge them into one mesh per piece and fit the budget.
