# Contract: unit model rig and blockouts

Owner: client stream. Readers: anyone who makes unit models (blockouts now, real art later), the piece-script and animation code, the model pool. Source: guide 14.2, 15.2, 20.2; decisions C-4 (axes), C-6 (blockout format).

## 1. Model

A unit model is a `Model` named after the def's `model` field (today always the def ID), stored in `ReplicatedStorage.Models`.

| Rule | Value |
|---|---|
| Root part | a `BasePart` named `base`, `Model.PrimaryPart = base`, **anchored** |
| Pieces | one `BasePart` per name in the def's `pieces` (except `muzzle`), named exactly that |
| Muzzle | an `Attachment` named `muzzle` (or `muzzle2`, ... for extra weapons) under the piece that carries it, at the barrel tip, its forward (−Z) along the barrel |
| Joints | each non-root piece has one `Motor6D` named after the piece, parented to the piece; `Part0` = its parent piece, `Part1` = the piece |
| Decoration | any other part (tracks, hatches, panels) is welded to one piece with a `WeldConstraint` and moves with it; its name is never a piece name |
| Collisions | every part: `CanCollide`, `CanQuery`, `CanTouch` = false; `CastShadow` = true for the hull only (optional) |
| Anchoring | only `base` is anchored; everything else is unanchored and held by joints and welds |
| Team color | parts that take the team color carry the CollectionService tag `TeamColor` |
| Attributes on the Model | `RootOffset` (CFrame): `base`'s CFrame relative to the unit origin (see 2); `FootprintStuds` (number, optional) |

Pieces only ever move through `Motor6D.Transform` (client animation, guide 14.3–14.5). Never set `C0`/`C1` at runtime, never use physics.

## 2. Axes and origin (C-4)

- **Unit origin:** on the ground, under the unit's center (the sim's position). Model space: +Y up, **forward = −Z** (Roblox `LookVector`), right = +X.
- **Placing a unit:** the sim's heading `h` (radians) points along `(sin h, cos h)` in world X/Z, so
  `unitCFrame = CFrame.new(x, groundY + alt, z) * CFrame.Angles(0, h + math.pi, 0)` and
  `base.CFrame = unitCFrame * model:GetAttribute("RootOffset")`.
  `groundY` is the drawn ground (`World.groundY`: the smooth terrain surface of C-28, or the water surface for floating units).
- **Turret yaw:** the joint's pivot is the turret's rotation center; `Transform = CFrame.Angles(0, yaw, 0)`, with `yaw` the sim's turret angle relative to the hull (radians, same sense as heading).
- **Barrel pitch:** the joint's pivot is the trunnion; `Transform = CFrame.Angles(pitch, 0, 0)`, pitch up positive (a −Z barrel rises).
- **Wire decoding** (Schema): heading `u8 → v / 256 · 2π`; aim yaw and pitch `u8 → v / 255 · 2π − π`.
- Joint `C0` (in `Part0` space) and `C1` (in `Part1` space) both locate the pivot, so `Transform = identity` is the rest pose (turret forward, barrel level).
- **Piece scripts (C-30)** write `Transform = CFrame.Angles(rx, ry, rz) * CFrame.new(offset)`: turn about the pivot, then move along the turned axes (a barrel's recoil runs along the barrel). A pooled model goes back with every `Transform` reset to identity.

## 3. Sizes

- One grid cell is 8 studs. A footprint-1 tank fits in about 6 × 8 studs (X × Z) and is 3–5 studs tall.
- Muzzle height should be close to the sim's firing height so tracers and projectiles start at the barrel (the sim's projectile spawn position wins).
- Silhouette first (guide 20.1): the role must read as a black shape from the game camera.

## 4. Blockout format (C-6)

Blockouts are placeholder models built from Parts by the generator (guide 20.2). One module per unit: `src/shared/Defs/Blockouts/<id>.luau` (client-owned folder, not part of the defs hash).

```lua
--!strict
return {
	id = "ord_lancer",            -- must match the file name and a unit def
	parts = {                     -- built in order; a part's parent must come earlier
		{ name = "base", shape = "box", size = { 5.6, 1.6, 7.6 }, at = { 0, 1.4, 0 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.2, 1.4, 8 }, at = { -2.9, 0.7, 0 }, color = "track" },
		{ name = "turret", parent = "base", shape = "box", size = { 3.4, 1.2, 3.6 }, at = { 0, 2.8, 0.4 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 4.5 },
		  at = { 0, 2.9, -3.4 }, pivot = { 0, 2.9, -1.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.9, -5.6 } },
	},
}
```

| Field | Meaning |
|---|---|
| `name` | a piece name from the def's `pieces` or `visualPieces` (gets a `Motor6D`) or a decoration name (gets a `WeldConstraint`) |
| `parent` | the piece it hangs from; required for everything except `base` |
| `shape` | `box`, `wedge`, `cylinder`, `ball` |
| `size` | `{ x, y, z }` studs. For `cylinder` the length is along `axis` |
| `axis` | `cylinder` only: `"x"`, `"y"` or `"z"` (default `"x"`, Roblox's own cylinder axis) |
| `at` | the part's center in model space (section 2), studs |
| `rot` | `{ x, y, z }` degrees, optional (wedges usually need it) |
| `pivot` | joint pivot in model space, pieces only; default = `at` |
| `color` | palette key: `hull`, `dark`, `track`, `metal`, `glass`, `team` (`team` also tags `TeamColor`), `hazard` (warning yellow, every faction) |

`visualPieces` (optional) lists extra jointed pieces only the client animates (piece scripts, C-30) that the def doesn't list yet, e.g. the Juggernaut's `armL` / `armR`; they must be parts and not repeat a def piece.

`attachments` places Attachments (`muzzle`, later `exhaust`, `rotorHub`, ...) in model space under a piece.

The generator checks: every def piece except `muzzle` is a part, `muzzle` is an attachment, names are unique, parents exist and come first, sizes are positive. The faction picks the palette (M-16, style guide: Order light sand-grey with cyan glass; Chaos gunmetal with orange glass), so Order and Chaos read apart at a glance.

## 5. Model pool contract (guide 15.2)

- Taking a model: clone from `ReplicatedStorage.Models.<model>` (or reuse a pooled one), color `TeamColor` parts, reset every `Motor6D.Transform` to identity, parent to `workspace.Units`.
- Releasing a model: reset joints, parent it to a hidden folder (not destroyed).
- All tactical unit roots move with one `workspace:BulkMoveTo` per frame (`Enum.BulkMoveMode.FireCFrameChanged`).

## 6. Team color (blockouts and meshed models)

Team color is applied at runtime, never baked: one model per unit serves every team. The method, which `ModelPool.acquire` already uses:

- **What to set:** `BasePart.Color = TeamColors(team)` on every `BasePart` in the model that has the CollectionService tag `TeamColor`. Nothing else changes per team: not `SurfaceAppearance.Color`, not the maps, not the emissive properties.
- **Blockouts:** the tagged parts are the `team`-colored parts; their `Color` is the panel color.
- **Meshed models** (pipeline.md): the tagged pieces are MeshParts with a `SurfaceAppearance` in `AlphaMode.Overlay`. Their color map's alpha is the team mask: 1 on painted metal, 0 on the team panels, in between on panel edges and crevices. The rendered albedo is

  `albedo = lerp(BasePart.Color, ColorMap.rgb × SurfaceAppearance.Color, ColorMap.alpha)`

  so where the alpha is 0 the panel is the team color, and where it is 1 the paint is unaffected. `SurfaceAppearance.Color` stays white (1, 1, 1): tinting it would recolor the whole model. Normal, roughness and metalness maps still apply on the panels, so they keep their bevels and seams.
- **Emissive:** the pieces don't glow; the glow lives in separate glow parts (fx.md, "Unit glow"; section 7). Glow parts are never tagged `TeamColor`: their `BasePart.Color` is their channel tint and never changes with the team.
- **Untagged pieces** (a barrel without team panels) keep their color map's alpha at 1, so their `BasePart.Color` has no effect.

Checked in "FTGG Art" with the four first team colors on both BAR tanks (`debug_out/screens/team_*.jpg`, models progress 2026-10-22).

## 7. Mesh manifest (meshed models, M-23)

Owner: models stream. `src/shared/Defs/Meshes/Registry.luau` lists every BAR-style mesh, so the game can build or check a meshed model without opening "FTGG Art". It's generated by `python assets/models/tools/manifest.py` from each mesh's `export/rig.json` and `roblox_assets.json`; don't edit it by hand. **Every new or changed mesh goes into the manifest in the same commit as its upload.** Like the blockouts, it isn't part of the defs hash.

**Materials file (client, C-103):** game scripts can't set `SurfaceAppearance` maps, `EmissiveMaskContent` or `RenderFidelity` (they need plugin rights), so the client clones prebuilt SurfaceAppearances from `ReplicatedStorage.MeshMaterials`, which Rojo builds from `place/MeshMaterials.model.json`. That file is generated from this manifest: **after `manifest.py`, run `lune run mesh_materials` and commit both together** (`lune run test_client MeshMaterials` fails while the file is stale). Flipping a `status` counts as a manifest change.

```lua
local Meshes = require("@shared/Defs/Meshes/Registry")
Meshes.glowMask            -- the white emissive mask every glow part uses
Meshes.units.ord_lancer    -- by unit def ID; Meshes.fx.shield_emitter for effect devices
```

| Field | Meaning |
|---|---|
| `status` | `"approved"` (the user approved the look: use it in game) or `"review"` (uploaded, waiting for review: keep the blockout); `note` says what's under review |
| `model` | the Open Cloud Model asset (all MeshParts, as uploaded) |
| `pieces` | by piece name (the def's `pieces`): `mesh` (MeshId), `center` and `size` in model space (section 2, studs), `parent` and `pivot` (joint pivot, model space) for every piece but `base` |
| `attachments` | `muzzle`, `muzzle2`, … (and e.g. the emitter's `core`; the nanoframe's `buildpad` and `nano1`, `nano2`, …, section 8): `parent` piece and `at` (model space) |
| `teamPieces` | the pieces tagged `TeamColor` (section 6) |
| `maps` | the SurfaceAppearance images: `ALB` (color map, alpha = team mask), `NOR`, `RGH`, `MTL`, `EMI` (the baked emissive mask, kept for reference; glow parts use `glowMask`) |
| `glow` | the glow parts: `name` (`<piece>_glow_<channel>`), `piece` it's welded to, `channel` (`running`, `head`, `power`, `weapon`), `tint` (RGB 0–255), resting `strength`, `center`, `size`, `mesh` (docs/contracts/fx.md, "Unit glow") |
| `glowShare`, `triangles` | measured coverage of the glow and the triangle count, for reference |
| `wreck` | optional, the wreck version (M-24, fx.md "Wrecks"): `status` (`"approved"` / `"review"`, its own review, separate from the live mesh's; `note` while under review), `model`, `pieces` (by the same piece names: `mesh`, `center`, `size`; parents and pivots are the live entry's), `maps` (`ALB`, `NOR`, `RGH`, `MTL`), `triangles`. No glow parts, no team pieces |

**Building a model from an entry** (what the rig tool does in "FTGG Art", `assets/models/tools/rig_model.luau`):
- every MeshPart (pieces and glow parts) gets `Size = size` and `CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi, 0)` in model space (the meshes come in turned 180° about Y);
- `base` carries the unit origin: `RootOffset = CFrame.new(base.center) * CFrame.Angles(0, math.pi, 0)`;
- joints at the pivots (section 1), glow parts welded to their piece;
- every piece gets a `SurfaceAppearance` from `maps` (`AlphaMode.Overlay`, `EmissiveStrength` 0);
- every glow part gets a `SurfaceAppearance` with no color map: `BasePart.Color` = tint, `EmissiveTint` = tint, `EmissiveMaskContent` = `glowMask`, `EmissiveStrength` = strength, `RenderFidelity.Precise` (in a game script: through `AssetService:CreateMeshPartAsync`'s options, and the SurfaceAppearances cloned from `ReplicatedStorage.MeshMaterials`, see above).

**Checks** (`lune run test_client Meshes`): every entry's pieces are exactly the def's pieces (muzzles as attachments), parents and glow pieces exist, team pieces are pieces, channels are known, and every asset ID is present. A `wreck` has exactly the live entry's pieces, except that it may leave out the mesh's own animated sub-pieces (`visualPieces`, section 9): their geometry then stays merged into the parent, and nothing moves on a wreck. Every rebuilt wreck so far carries them all.

## 8. Construction anchors (nanoframe, M-25)

Owner: models stream. Attachments for the client's BAR-style nanoframe, on every factory (vehicle plants, airfields, shipyards and their advanced versions, both factions) and every constructor (every def with a `nano` piece, Commanders included). They are in the blockouts (`attachments`, section 4) and in the mesh manifest (`attachments`, section 7), at the same places.

| Attachment | On | Meaning |
|---|---|---|
| `buildpad` | factories, parent `base` | where the unit in production sits, centred on the pad (vehicle plants: the ramp or bay; airfields: the landing pad or under the open hangar; shipyards: in the slip at the waterline, y = 0). Its forward (−Z) faces the exit: every factory exits at model −Z (the sim spawns a finished unit one cell out along the factory's heading), so it carries no rotation |
| `nano1`, `nano2`, … | factories (parent `base`): at the emitters and build lights (door jambs and lintel, crane trolleys, lamps under gantries and roofs); constructors (parent `nano`): at the emitter at the tip of the `nano` piece, so they turn with it | where nano-spray starts; spray from every one of them to the frame |

Constructors use `nano1`, not `nano`: an Attachment named like the `nano` piece would make `FindFirstChild("nano", true)` ambiguous, and factories and constructors then share one lookup (`nano1` … `nanoN`, stop at the first missing).

Mesh anchors live in `assets/models/tools/anchors.py` (final model space); `tools/unit.py` merges them into `rig.json`, and `python assets/models/tools/anchors.py --patch` writes them into existing exports without a rebuild. A new factory or constructor gets its anchors in the same commit as its blockout or mesh.

## 9. Animated pieces (M-27)

Owner: models stream. Every part that should move is its own jointed piece with its pivot where it turns or slides, so the client can animate it. **No geometry changed:** existing shapes were split into pieces. Each animated piece carries `anim = { motion, axis, range? }`, with `axis` in model space and a positive rotation as the opening / forward direction:
- **meshes:** the manifest entry's `anim` (by piece name), with the pieces that exist only for animation listed in its `visualPieces` (section 7);
- **blockouts:** an `anim` field on the part itself. A part with `anim` is jointed like a visual piece (`Blockout.pieceSet`; `Blockout.anims(bp)` lists them).

| Motion | Meaning | Pieces |
|---|---|---|
| `spin` | continuous rotation about `axis` | helicopter `rotor` (Y) and `tailRotor` (X); windmill `rotor` (Z); wheels `wheelL1..N` / `wheelR1..N` (X); jammer emitters (Y): Veilspire `band`, Curtain `tip`, Smog / Blackout `spine` (the rods ride on it) |
| `turn` | slow rotation or sweep about `axis` (Y) | `radar`, `dish`, `array`, `radarPanel`, `mastArray` (radar dishes and arrays, airfield and ship radars, the Sentry's mast); extractor `drill`; crane `jib`, `deckJib`, `deckCrane`; sonar station `drum` / `ring` |
| `scroll` | a track set: the band with its road wheels, as one piece (`trackL`, `trackR`, axis X). Bob or judder it with speed. The band's UVs run along its length, so a texture offset can fake the movement | every tracked unit |
| `slide` | translation along `axis` up to `range` studs | factory `trolley` (Order shipyard gantry, Chaos vehicle plant crane rail) |
| `open` | rotation about `axis` up to `range` degrees | silo `hatch` / `hatch2`, bomber `bay`, beam tower lids `shellL` / `shellR`, the anti-nuke `hatch` |
| `lower` | translation along `axis` up to `range` studs | dipping `sonar` (ASW helicopters, torpedo launchers) |
| `pulse` | scale and emissive pulse about the pivot | shield generator / fusion / generator `core` |
| `swing` | an oscillating hinge about `axis`, driven by the client's walk cycle (and an arm's gesture) | walker joints: hips, thighs, shins, feet, arms (section 10) |

The piece names stay the same in a unit's blockout, mesh and wreck, so one piece script serves all three. Builders' `nano` and weapon pieces (`turret`, `barrel`, `launcher`, …) are driven by the sim's aim model as before and aren't listed here. Factories' gantries, cranes and conveyors, extractor drill heads, and generator / fusion cores get their pieces as each structure is redesigned at its new size (size scale, M-26).

How it's built (models stream): `with p.sub(name, pivot, motion, axis, range)` in a build script moves the shells made inside the block into their own piece (`tools/lib.py`); `unit.wheel(..., name=)` and the shared hulls do it for wheels and track sets. `tools/animate.py` lists `anim` for pieces that were already pieces.

## 10. Walkers (the Commander mechs, M-31)

The Commanders (`ord_sovereign`, `chs_warlord`) are walking mechs. The def keeps its pieces (`base`, `nano`); the rest are visual pieces (`visualPieces`, each with an `anim`), all jointed at their pivots:

| Piece | Parent | Motion | What it is |
|---|---|---|---|
| `base` | – | – | the pelvis (the root; it bobs a little on each step: `dy`) |
| `torso` | `base` | `turn` Y | chest, shoulders, backpack; turns towards the build or weapon target |
| `head` | `torso` | `turn` Y | the sensor head (Order) / the low head with the eye slits (Chaos) |
| `armL` | `torso` | `swing` X | the left upper arm, on the shoulder |
| `nano` | `armL` | (the def's piece, aimed like a builder's `nano`) | the build forearm: the emitter (Order) / the claw arm (Chaos); the `nano1` attachment at the emitter |
| `armR` | `torso` | `swing` X | the right upper arm |
| `forearmR` | `armR` | `swing` X | the weapon pod (Order) / the heavy gun (Chaos); the `muzzle` attachment at its mouth |
| `hipL`, `hipR` | `base` | `swing` X | the hip yokes |
| `thighL`, `thighR` | `hip*` | `swing` X | the thighs |
| `shinL`, `shinR` | `thigh*` | `swing` X | the shins (a negative swing bends the knee back) |
| `footL`, `footR` | `shin*` | `swing` X | the feet (a positive swing lifts the toe) |

A positive swing about X turns a part's lower end forward (towards −Z). The legs rest with a real knee bend (the thigh runs down and forward to the knee, the shin back down to the ankle). The review pose `poses.<id>.stride` in `Blockouts/Pending/Registry.luau` is one frame of the walk: the left leg forward (Order: thigh +24°, shin −8°, foot −16°), the right leg back (thigh −18°, shin −22°, foot +30°), the arms against the legs, the torso turned about 6° and the pelvis 0.2 lower. A walk cycle alternates it, about one stride per 0.8 s at full speed (the heroic mechs, M-32, take longer strides than v1).

