# Mesh pipeline

**Status: proposal, waiting for approval (2026-10-21).** Once the Lancer vertical slice is built, this becomes the repeatable workflow with the exact commands and settings that worked.

From a script in the repo to a rigged MeshPart model in Studio, for one unit at a time. Look: [`style-guide.md`](style-guide.md). Rig: [`../contracts/rig.md`](../contracts/rig.md).

## Choices

- **Blender 5.2, headless, scripted.** `blender -b --factory-startup -P <script>`: no Blender window, nothing for you to run. No Blender connector exists in the MCP registry; the scripts do the same thing and can be rerun.
- **Modeled from parametric Python, not an AI base mesh.** Generated meshes of hard-surface vehicles come as one lumpy piece with messy topology; splitting them into rig pieces and retopologizing them to 1,500 triangles costs more than modeling from boxes and bevels. Scripted models are exact to the def's footprint, rig pivots and budget, and every number is reviewable in a diff.
- **One texture set per unit** (1024 × 1024: color, normal, roughness, metalness), shared by its pieces.
- **Team color by mask, not extra parts:** the color map's alpha is 0 on the team panels (turret roof, hull top). In `SurfaceAppearance.AlphaMode = Overlay` (the default) those pixels show the MeshPart's own `Color`, which the model pool already sets on parts tagged `TeamColor` (rig.md 5).

### AI base mesh: options and licenses (not recommended for the Lancer)

| Generator | Commercial use of outputs | Fit |
|---|---|---|
| Studio's `generate_mesh` (Roblox Cube, hosted) | Made inside Roblox under Roblox's terms, for use on Roblox | Stays in Studio as up to 8 parts, no clean path into Blender; hard surfaces come out soft |
| Roblox Cube 3D open weights | Research-only license (Cube3D Research-Only RAIL-MS): no commercial use | Not usable |
| Meshy | Free plan: CC BY 4.0, commercial with credit to Meshy; paid plans: commercial, no credit | Usable as a reference or for props |
| Tripo | Paid plans: commercial; free-plan terms are contradictory between Tripo's own pages | Paid only |
| Microsoft TRELLIS / TRELLIS.2 | MIT (code and weights), commercial allowed; hosted versions (e.g. NVIDIA NIM) add their own terms | Needs a 16 GB+ GPU (this PC has 6 GB) or a host |
| Tencent Hunyuan3D 2.x | Community license: not valid in the EU, UK or South Korea; above 1 million monthly users needs Tencent's permission | Avoid for a Roblox game |

If you want a generated base anyway: Meshy on a paid plan (cleanest terms) for props and structures (guide 20.5), with credits in `CREDITS.md`.

## Files

```
assets/models/
  tools/
    lib.py               Blender helpers: primitives, bevels, UVs, bakes, export, checks
    rig_model.luau       Studio rig script (run through execute_luau)
  ord_lancer/
    build.py             the Lancer: dimensions, pieces, camouflage seed
    export/
      ord_lancer.fbx     three meshes: base, turret, barrel (Y up, 1 unit = 1 stud)
      ord_lancer_ALB.png color + team mask in alpha (1024)
      ord_lancer_NOR.png normal (1024)
      ord_lancer_RGH.png roughness (1024, grey)
      ord_lancer_MTL.png metalness (1024, grey)
      rig.json           pivots, muzzle, RootOffset, footprint, triangle counts
```

`.blend` files are build output (gitignored); a unit is about 3–5 MB in git (the PNGs).

## Steps

1. **Model** (`build.py`, headless): low-poly hull, tracks, road wheels and skirts in `base`; `turret`; `barrel`. Object origins at the joint pivots (turret ring center, trunnion); the muzzle is an empty, written to `rig.json`. Budget target: ≤ 1,500 triangles for the whole unit (hull about 800, turret about 500, barrel about 150).
2. **High-poly copy** in the same script: bevels, panel cuts, sensor strips, bolts. Baked into the low-poly's normal map, never exported.
3. **UVs:** each piece unwrapped into its own region of one shared 1024 atlas, about 10 pixels per stud.
4. **Bake** (Cycles; the GTX 1660 Super handles it): normal from the high-poly; base color = sand with a seeded two-tone disruptive camouflage, edge wear and ambient occlusion; team mask into alpha; roughness and metalness from material IDs (paint, bare metal, rubber, glass).
5. **Export:** FBX with the three meshes, the four PNGs, `rig.json`. A check fails the build if names, pivots, footprint or budget are off.
6. **Import (needs you):**
   - **A, recommended for the slice:** in "FTGG Art", File → Import 3D → `ord_lancer.fbx`. The importer uploads the meshes and, when it picks up the PBR textures, builds the SurfaceAppearance. If it doesn't, the four PNGs go up through the Asset Manager (they pass moderation first). A few clicks per unit.
   - **B, for the rest of the roster:** an Open Cloud API key with asset write permission for your account (or group), kept in an environment variable, never committed. A `lune run upload_model <id>` script uploads the FBX and PNGs, and I insert the uploaded asset into "FTGG Art" by its ID. No clicks after setup.
7. **Rig** (`rig_model.luau` through `execute_luau`): `base` anchored and primary, one `Motor6D` per piece at the `rig.json` pivots, the `muzzle` Attachment, collisions off, `TeamColor` tags on the masked pieces, `RenderFidelity = Automatic` (Roblox's automatic level of detail), `RootOffset` and `FootprintStuds` attributes; saved as `ReplicatedStorage.Models.ord_lancer` in "FTGG Art". The client already uses that model over the blockout (`Render/Models.luau`).
8. **Test in "FTGG Art"** next to the part-built blockout, on the Coastline terrain: pitch 35°, 55° and 80° at close (about 40 studs), normal (220) and far (450, the last distance before strategic icons) plus max (900). Frame time in a playtest: 100 meshed Lancers vs 100 blockouts vs none, average and worst frame over 10 seconds.
9. **Report:** triangles per piece, texture sizes, frame times, screenshots, against guide 20.1.

Getting the model into the game place "For The Greater Good" is the client session's step (a request in `docs/progress/models.md`).
