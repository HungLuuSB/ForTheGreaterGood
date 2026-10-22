# Art style guide

How units and structures look. Sources: design guide 2.1 and 20; decisions `M-` in [`../decisions/models.md`](../decisions/models.md). The rig (axes, pieces, joints) is [`../contracts/rig.md`](../contracts/rig.md). The production steps are in [`pipeline.md`](pipeline.md).

## Look (M-15)

**Beyond All Reason's model style on near-future military shapes.** The forms stay ours (Leopard 2 / Abrams / T-14 base forms, the faction rules below); the rendering follows BAR's RTS conventions:

- **Clean hard-surface shapes, strong silhouettes.** Proportions are slightly exaggerated for the RTS camera: turrets and guns bigger than real ones (about 15–25 % on a tank), details chunky enough to read at normal zoom.
- **Painted metal, no camouflage.** One base paint per faction, with crisp panel lines and light edge highlights baked into the textures; ambient occlusion in the creases. Wear is limited to the edge highlights: no dirt, streaks or chipping.
- **Large, bold team-color panels designed into the model:** turret roof, hull top and side plates. They are shapes of their own (bevelled plates), not decals, and read at normal zoom (220 studs).
- **Small emissive details** as the sci-fi accent: sensor lights, optics, a glowing strip on the gun. Small and few; never whole surfaces.
- **Readability first:** silhouette, then secondary shapes, then small details only if they're cheap.

**References:** BAR screenshots in [`../../assets/reference/bar/`](../../assets/reference/bar/README.md) are for style only. Never download or copy BAR's model files or textures (or anyone else's): every model and texture is made in this repo.

## Factions

Gameplay identity (A's [`../design/factions.md`](../design/factions.md), 2026-10-22): **Order is the heavy side**, tougher, slower and more expensive; **Chaos is the light side**, faster and cheaper, built for numbers. The armor reads the gameplay (M-14).

| | **Order**: heavy defense and strategy | **Chaos**: the strength of armies |
|---|---|---|
| Based on | Western equipment: Leopard 2, Abrams, Patriot | Eastern equipment: T-14 Armata, T-90M, Pantsir |
| Character | Sleek, wedge-shaped, high-tech, fortress-like: heavy | Rugged, aggressive, built for mass and assault: light and nimble |
| Shapes | Wedge armor, flat faces, long, low and broad; massive | Rounder or domed turrets; compact: shorter, narrower, higher off the ground |
| Signature details | Thick armor plates and add-on modules, sensor strips, shields, active protection | Visible reactive-armor blocks, slat cages at the rear, more weapons per vehicle, exposed running gear |
| Paint | Light sand-grey (178, 174, 160; the mesh bakes a slightly warmer (174, 168, 150) with rougher paint so it draws like the blockout, M-18); trim a darker warm grey | Gunmetal (86, 90, 95; lifted from 76, 80, 84 so it reads at 35°, M-18); trim near-black; bright edge highlights |
| Emissive accent | Cool cyan (90, 210, 255) | Hot orange (255, 140, 50) |

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

- **Hulls:** long, low and wide, skirts (deep for Order, partial for Chaos), a track belt on the ground.
- **Turrets** set toward the rear and oversized for the RTS camera, **long, thick guns**, sights and sensor boxes on the roof.
- **SAMs:** canister launchers. **Radars:** flat phased arrays, never dishes.
- **Team color:** bold panels (the team color at full strength, a thin dark outline from the panel's bevel) on the turret roof, the hull top and the side plates. About a quarter of the area seen from 55° should be team color. Roofs come first: the camera looks down at 35°–80° (55° by default).
- **Emissive:** an emissive mask in the texture set, for sensor glass, lights and a strip on the gun; the faction's accent color.
- **Never:** camouflage, dirt, rust, exposed engines, smoke stacks, crates, pistons, round dishes, decal-like team markings, toy proportions (oversize turret on a short hull: exaggerate the turret and gun, not the hull).

## Glow (the emissive pass, M-22)

The standard for every BAR-style mesh, new ones included:

- **Glow has a job.** Faction accent (Order cool cyan / white, Chaos hot amber / orange) on things that would light up: sensors and sensor eyes, running and tail lights, engine exhausts, reactor and generator cores, extractor drills, factory doors and build lights, the muzzle area. Never glow for decoration only.
- **Never team-colored.** Team color stays on the painted panels. Headlights are neutral warm white on both factions.
- **Small and bright beats big and dim.** About 5–10% of the visible surface; it must still read at 55° and 220 studs without washing out the team panels. Large flat buildings sit lower (2–3%): concentrate their glow at the door and the working parts, not on the roof.
- **All in the emissive mask**, never `Light` objects: in Blender, glowing faces use the kinds `light` (running), `head`, `power` and `weapon` (`assets/models/tools/unit.py`); the runner bakes them into the maps and splits each kind into its own glow part, so the client can drive the channels apart (docs/contracts/fx.md, "Unit glow"). In Studio a glow part's color is its channel tint (`BasePart.Color` and `EmissiveTint`, no color map); a white albedo washes the glow out to white.

## Size

Models match their def's footprint: one cell is 8 studs, and a footprint-1 vehicle fits in about 6 × 8 studs (rig.md 3). The gun may reach past the footprint. Check every model from the game camera at 35°, 55° and 80° pitch, at close, normal and maximum zoom.

## Budget (guide 20.1)

Under review (M-12): the Lancer is under a 4,000-triangle cap, with one 1024 set (color, normal, roughness, metalness, emissive mask) and Roblox's automatic level of detail; per-class budgets are proposed in [`pipeline.md`](pipeline.md). Guide 20.1's 300–1,500 was for simple low-poly art.

## Lessons so far

- A turret as wide as the hull blends into it from above: keep the turret narrower and set back, so it shows as its own shape.
- Team color through a dark wash reads navy at 220 studs; panels need the team color at full strength (Lancer review 2).
- Camouflage works as camouflage: it hides the unit. The RTS needs the opposite (M-15).
- All tanks share one outline by design, so faction identity comes from shapes on top of it (wedges vs domes, sensor strips vs reactive-armor blocks and cages) and from the paint.
- Low hulls put the muzzle at about 2.3–2.5 studs, below the sim's 3.6-stud firing height; the mesh's muzzle attachment is where effects start (rig.md 3).

## Base color test (Chaos, 2026-10-21)

Olive (80, 86, 60) vs gunmetal (76, 80, 84) on the Ravager variants, on the Coastline terrain's grass and beach in "FTGG Art", with the sand Lancer for reference; pitch 35°, 55° and 80°, at 80, 220 (normal), 450 (just inside the icon switch, C-17) and 900 studs (max).

- **Olive** disappears into the grass at every pitch: realistic camouflage, poor readability. On sand it reads, but most of the map is grass.
- **Gunmetal** stays a distinct cool grey on grass and sand, and reads apart from Order's warm sand at a glance.
- **At 900 studs** every unit is a few pixels and the game draws strategic icons instead (beyond 480), so color only matters up to about 450.

**Recommendation: gunmetal.** If it looks too blue under the final lighting, warm it slightly rather than greening it. Screenshots: `debug_out/screens/color_*.jpg`.
