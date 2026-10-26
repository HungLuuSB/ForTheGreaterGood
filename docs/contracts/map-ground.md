# Contract: baked map ground (mesh tiles)

Owner: client stream. Maker: models stream. Readers: Render/MeshGround, Render/Ground, `lune run mesh_materials`. Decision: C-167.

Roblox's voxel terrain draws far ground coarse and sharpens it over seconds after a camera jump, and scripts can't change that. Ground built at runtime as an EditableMesh runs out of the device's editable-memory budget long before a whole map (Render/FogBlanket's note: about 7,600 vertices in the Studio client). So the named maps' ground is baked offline into ordinary uploaded mesh tiles, which keep full detail at any distance.

## 1. Input: `lune run export_ground [mapId | all] [outDir]`

Writes `<outDir>/<name>/ground.json` (default `assets/maps`) for every named and hand-made map (`map:canyon`, `map:normandy`, `map:ridgeline`, `map:coastline`, `map:twin_lakes`, `map:crossroads`). Format `ftgg-ground/1`:

| Field | Meaning |
|---|---|
| `origin` `{x, z}`, `size` `{sx, sz}` | the map's corner and size in studs (centre (0, 0); north = −Z) |
| `cells` `{w, d}`, `cellSize` | grid cells (8 studs) |
| `step`, `vertices` `{nx, nz}` | height samples every `step` studs (4) from `origin`, `nx` × `nz` of them |
| `heights` | `nx * nz` numbers, x fastest: the drawn ground height (studs). **The baked surface must match it** (units, rings, deposits and effects stand on this surface: Core/Terrain.groundY) |
| `materialPalette`, `materials` | per cell (x fastest) an index into the palette: the ground type the client draws there (`grass`, `rock`, `sand`, `road`, `leafy`, `ground`, `bridge`, `desert`, `redrock`) |
| `featurePalette`, `features` | per cell, a hand-made map's feature (`mesa`, `cliff`, `apron`, `badlands`, `boulder`, `floor`; Normandy's `hedge`, `house`, `bluff`, ...): where rock detail belongs |
| `waterLevel`, `water` | the flat water surface (or null) and each cell's water depth (0 = dry). Water stays drawn by the client; bake only the ground (the sea bed too) |
| `deposits` | `{cx, cz, value}`: supply deposits. Keep the ground flat there (the deposit models sit on it) |
| `starts` | `{x, z}` start positions (flat plateaus) |

## 2. Output: the mesh manifest's `ground` table

In `src/shared/Defs/Meshes/Registry.luau` (the models stream's manifest), next to `units` and `fx`:

```lua
ground = {
	canyon = {                        -- the map name (MapRegistry key)
		status = "review",            -- "approved" shows it in game; "review" only with Invoke("groundanyway", true) in Studio
		step = 8,                     -- optional: the bake's height sampling in studs when coarser than the export's 4 (`coarsen`, C-235)
		tiles = {                     -- the ground surface, split so no mesh passes Roblox's triangle limit
			{ mesh = "rbxassetid://…", center = { x, y, z }, size = { sx, sy, sz }, material = "desert" },
			…
		},
		details = {                   -- optional rock detail: cliff faces, mesa rims, boulders
			{ mesh = "rbxassetid://…", center = { x, y, z }, size = { sx, sy, sz }, material = "redrock" },
		},
	},
},
groundMaterials = {                   -- one per material key used above
	desert = { maps = { ALB = "rbxassetid://…", NOR = "…", RGH = "…", MTL = "…" } }, -- the same map keys as the units entries
	redrock = { maps = { … } },
},
```

- **World space:** `center` and `size` are the MeshPart's world position and size. Export the meshes the way the unit meshes are exported: the client applies the same 180° turn about Y as Render/MeshModels (`CFrame.new(center) * TURN`).
- **One material per tile.** A tile that crosses ground types is split into one mesh per type; the seams follow the type borders (smooth wavy lines cut through the triangles, M-35; the surface is unchanged). Rock detail can cover cliff seams.
- **UVs in world space**, `u = x / 32`, `v = z / 32` (one texture repeat every 32 studs), so a texture tiles across tiles without seams.
- **Surface:** within 0.25 studs of `heights` at every sample; flat (within DEPOSIT_LIFT, 0.35) over deposits and start plateaus.
- **Coarser bakes (`step`, C-235):** a big map may keep only every k-th sample (`coarsen`; the Lakelands every 8 studs). Then each square between kept samples is two flat triangles split along its flatter diagonal (`abs(h00 - h11) <= abs(h10 - h01)`: 00–11, else 10–01), and the entry says `step`. The client places everything on that same surface (Core/Terrain.drawnY), because the sim's cell centres the bake skips can be 2 studs off it at a cliff's foot.
- **Textures:** `lune run mesh_materials` writes a SurfaceAppearance `ground_<material>` per `groundMaterials` entry into `place/MeshMaterials.model.json`; the client clones it onto that material's tiles. Without one, the tile gets a plain Roblox material and colour (Render/MeshGround's fallbacks).
- Uploads go to the user's account with the user's approval, as for unit meshes.

## 3. In game

- **When it's used:** Render/Ground builds the mesh ground when the map has an `approved` entry (or `review` with the Studio switch). Roblox terrain then draws only the water. Maps without an entry keep the voxel terrain.
- **Tiles:** built in parallel at the map load (CreateMeshPartAsync from the asset IDs, no editable memory), `RenderFidelity.Precise`, anchored, `CanCollide` off, `CastShadow` on. Tiles have `CanQuery` off and a box collision (C-209: a tile's box would catch clicks at mesa height; ground clicks march the sim's heights instead). Details get a convex-decomposition collision (`Default`, ~40 ms each) and `CanQuery` on, tagged `GroundDetail`: the fog of war blanket samples their real height (they stand above `heights` on mesas), and clicks look through them (C-213). When the mesh ground has finished loading, the blanket is rebuilt over it.
- **Gameplay** never reads the meshes: heights come from the sim's layers (Core/Terrain), so a slightly wrong bake shows as units floating or sinking, nothing worse. On a coarser bake the client draws units on the bake's surface rebuilt from those layers (`World.groundY` with `world.drawnStep`, C-235), not on the meshes themselves.
