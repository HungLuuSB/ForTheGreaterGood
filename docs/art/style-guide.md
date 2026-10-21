# Art style guide

How units and structures look. Sources: design guide 2.1 and 20; decisions `M-` in [`../decisions/models.md`](../decisions/models.md). The rig (axes, pieces, joints) is [`../contracts/rig.md`](../contracts/rig.md). The production steps are in [`pipeline.md`](pipeline.md).

## Look

- **Near-future military, realistic-leaning.** Real modern vehicles as the base, with restrained sci-fi accents: angular armor panels, sensor strips, active-protection systems, rail-gun details.
- **Mood reference:** the textured realism of *World in Conflict*. Mood only: never copy its models or textures (or anyone else's).
- **Readability first:** silhouette, then secondary shapes, then small details only if they're cheap.

## Factions

Gameplay identity (A's [`../design/factions.md`](../design/factions.md), 2026-10-22): **Order is the heavy side**, tougher, slower and more expensive; **Chaos is the light side**, faster and cheaper, built for numbers. The looks stay; the weight of the armor follows the gameplay (M-14).

| | **Order**: heavy defense and strategy | **Chaos**: the strength of armies |
|---|---|---|
| Based on | Western equipment: Leopard 2, Abrams, Patriot | Eastern equipment: T-14 Armata, T-90M, Pantsir |
| Character | Sleek, wedge-shaped, high-tech, fortress-like: heavy | Rugged, aggressive, built for mass and assault: light and nimble |
| Shapes | Wedge armor, flat faces, long, low and broad; massive | Rounder or domed turrets; compact: shorter, narrower, higher off the ground |
| Signature details | Thick armor plates and add-on modules, sensor strips, shields, active protection | Visible reactive-armor blocks, slat cages at the rear, more weapons per vehicle, exposed running gear |
| Base color | Sand (186, 170, 132) | Gunmetal (76, 80, 84), recommended over olive (see "Base color test") |
| Camouflage | Two- or three-tone disruptive pattern in sand and its darker tones | Pattern in the chosen base and its darker tones |

### Reading heavy vs light

At the same footprint and role, an Order unit should look like it weighs more than its Chaos counterpart, from the game camera and as a silhouette.

| Cue | **Order (heavy)** | **Chaos (light)** |
|---|---|---|
| Plate thickness | Thick, visible at every edge (about 0.3–0.5 studs on a footprint-1 tank); big bevels | Thin plates (about 0.1–0.2 studs); armor added as separate blocks and cages |
| Armor coverage | Add-on modules stacked on the turret cheeks and hull front (spaced armor, wedges); few gaps | Gaps and open frames: slat cages, reactive-armor bricks with space between them |
| Skirts and wheels | Deep skirts covering most of the road wheels; tracks hidden | Short or partial skirts (rubber flaps), most road wheels and the track run visible |
| Stance | Low ground clearance, wide track; mass close to the ground | Higher ground clearance, narrower hull, a gap between hull and tracks |
| Volume | Broad, slab-sided turret with an armored bustle; full hull sides | Compact turret, gun long for the turret; equipment mounted outside (boxes, launchers, guns) |
| Proportions | Long and broad for the footprint | Shorter and narrower for the footprint, nose raised slightly |

Keep the faction's look under these cues: Order stays clean and wedge-shaped (heavy, not boxy); Chaos stays rugged (light, not flimsy or post-apocalyptic: still no exposed engines, stacks or rust).

## Rules for both

- **Hulls:** long, low and wide, skirts (deep for Order, partial for Chaos) with road wheels showing below, a track belt on the ground.
- **Turrets** set toward the rear, **long guns**, sights and sensor boxes on the roof.
- **SAMs:** canister launchers. **Radars:** flat phased arrays, never dishes.
- **Team color on top surfaces** (turret roof, hull top): the camera looks down at 35°–80° (55° by default), so roofs are what players see. At low pitch the sides show too, so they carry the camouflage and the faction's signature details.
- **Glass and sensors:** dark tinted; a thin emissive strip at most, never a glow.
- **Never:** exposed engines, smoke stacks, crates, pistons, rust, round dishes, bright saturated hulls, toy proportions (big turret on a short hull).

## Size

Models match their def's footprint: one cell is 8 studs, and a footprint-1 vehicle fits in about 6 × 8 studs (rig.md 3). The gun may reach past the footprint. Check every model from the game camera at 35°, 55° and 80° pitch, at close, normal and maximum zoom.

## Budget (guide 20.1)

Under review (M-12): the Lancer is 3,704 triangles against a 4,000 cap, with one 1024 set (color, normal, roughness, metalness) and Roblox's automatic level of detail; per-class budgets are proposed in [`pipeline.md`](pipeline.md). Guide 20.1's 300–1,500 was for simple low-poly art.

## Lessons from the part-built variants

- A turret as wide as the hull blends into it from above: keep the turret narrower and set back, so it shows as its own shape.
- Whole team-colored turrets look like toys; team color goes on panels on top surfaces only.
- All tanks share one outline by design, so faction identity comes from shapes on top of it (wedges vs domes, sensor strips vs reactive-armor blocks and cages) and from the base color.
- Low hulls put the muzzle at about 2.3–2.5 studs, below the sim's 3.6-stud firing height; the mesh's muzzle attachment is where effects start (rig.md 3).

## Base color test (Chaos, 2026-10-21)

Olive (80, 86, 60) vs gunmetal (76, 80, 84) on the Ravager variants, on the Coastline terrain's grass and beach in "FTGG Art", with the sand Lancer for reference; pitch 35°, 55° and 80°, at 80, 220 (normal), 450 (just inside the icon switch, C-17) and 900 studs (max).

- **Olive** disappears into the grass at every pitch: realistic camouflage, poor readability. On sand it reads, but most of the map is grass.
- **Gunmetal** stays a distinct cool grey on grass and sand, and reads apart from Order's warm sand at a glance.
- **At 900 studs** every unit is a few pixels and the game draws strategic icons instead (beyond 480), so color only matters up to about 450.

**Recommendation: gunmetal.** If it looks too blue under the final lighting, warm it slightly rather than greening it. Screenshots: `debug_out/screens/color_*.jpg`.
