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
| `color` | palette key: `hull`, `dark`, `track`, `metal`, `glass`, `team` (`team` also tags `TeamColor`) |

`visualPieces` (optional) lists extra jointed pieces only the client animates (piece scripts, C-30) that the def doesn't list yet, e.g. the Juggernaut's `armL` / `armR`; they must be parts and not repeat a def piece.

`attachments` places Attachments (`muzzle`, later `exhaust`, `rotorHub`, ...) in model space under a piece.

The generator checks: every def piece except `muzzle` is a part, `muzzle` is an attachment, names are unique, parents exist and come first, sizes are positive. The faction picks the palette (Order: clean light greys and blue glass; Chaos: dark iron and rust), so Order and Chaos read apart at a glance.

## 5. Model pool contract (guide 15.2)

- Taking a model: clone from `ReplicatedStorage.Models.<model>` (or reuse a pooled one), color `TeamColor` parts, reset every `Motor6D.Transform` to identity, parent to `workspace.Units`.
- Releasing a model: reset joints, parent it to a hidden folder (not destroyed).
- All tactical unit roots move with one `workspace:BulkMoveTo` per frame (`Enum.BulkMoveMode.FireCFrameChanged`).
