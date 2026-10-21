# Art style guide

How units and structures look. Sources: design guide 2.1 and 20; decisions `M-` in [`../decisions/models.md`](../decisions/models.md). The rig (axes, pieces, joints) is [`../contracts/rig.md`](../contracts/rig.md). The production steps are in [`pipeline.md`](pipeline.md).

## Look

- **Near-future military, realistic-leaning.** Real modern vehicles as the base, with restrained sci-fi accents: angular armor panels, sensor strips, active-protection systems, rail-gun details.
- **Mood reference:** the textured realism of *World in Conflict*. Mood only: never copy its models or textures (or anyone else's).
- **Readability first:** silhouette, then secondary shapes, then small details only if they're cheap.

## Factions

| | **Order**: heavy defense and strategy | **Chaos**: the strength of armies |
|---|---|---|
| Based on | Western equipment: Leopard 2, Abrams, Patriot | Eastern equipment: T-14 Armata, T-90M, Pantsir |
| Character | Sleek, wedge-shaped, high-tech, fortress-like | Rugged, aggressive, built for mass and assault |
| Shapes | Wedge armor, flat faces, long and low | Rounder or domed turrets, shorter and wider proportions |
| Signature details | Heavy armor, sensor strips, shields, active protection | Visible reactive-armor blocks, slat cages at the rear, more weapons per vehicle |
| Base color | Sand (186, 170, 132) | Gunmetal (76, 80, 84), recommended over olive (see "Base color test") |
| Camouflage | Two- or three-tone disruptive pattern in sand and its darker tones | Pattern in the chosen base and its darker tones |

## Rules for both

- **Hulls:** long, low and wide (Chaos a bit shorter and wider), skirts with road wheels showing below, a track belt on the ground.
- **Turrets** set toward the rear, **long guns**, sights and sensor boxes on the roof.
- **SAMs:** canister launchers. **Radars:** flat phased arrays, never dishes.
- **Team color on top surfaces** (turret roof, hull top): the camera looks down at 35°–80° (55° by default), so roofs are what players see. At low pitch the sides show too, so they carry the camouflage and the faction's signature details.
- **Glass and sensors:** dark tinted; a thin emissive strip at most, never a glow.
- **Never:** exposed engines, smoke stacks, crates, pistons, rust, round dishes, bright saturated hulls, toy proportions (big turret on a short hull).

## Size

Models match their def's footprint: one cell is 8 studs, and a footprint-1 vehicle fits in about 6 × 8 studs (rig.md 3). The gun may reach past the footprint. Check every model from the game camera at 35°, 55° and 80° pitch, at close, normal and maximum zoom.

## Budget (guide 20.1)

Units 300–1,500 triangles, structures up to 3,000, wrecks up to 500; one texture set per unit (color, normal, roughness, metalness) at most 1024 × 1024, Roblox's upload limit. Roblox's automatic level of detail takes care of distance.

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
