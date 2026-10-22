# Mesh pipeline

The repeatable workflow from a script in the repo to a rigged MeshPart model in Studio, one unit at a time (M-11, M-12). First run: the Lancer, 2026-10-21. Look: [`style-guide.md`](style-guide.md). Rig: [`../contracts/rig.md`](../contracts/rig.md).

## Tools

- **Blender 5.2, headless:** `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. No window, nothing to click; a unit builds in about 2 minutes on the CPU.
- **No AI base mesh for vehicles** (license survey below): generated hard-surface meshes need more cleanup than scripted modeling.
- **Roblox Studio**, place "FTGG Art": the 3D Importer (your clicks) and `execute_luau` for the rig.

## Files

```
assets/models/
  tools/
    lib.py            Blender helpers: shapes in Roblox space, materials, UV atlas, bakes, FBX, previews
    rig_model.luau    Studio rig: normalize the import, check against rig.json, joint, save
  <unit>/
    build.py          the unit: dimensions, pieces, pivots, camouflage, budget
    export/
      <unit>.fbx      base, turret, barrel (...) as separate meshes, textures embedded
      <unit>_ALB.png  color; alpha = team mask (0 = team color shows)
      <unit>_NOR.png  tangent-space normal (OpenGL, as Roblox)
      <unit>_RGH.png  roughness (grey)
      <unit>_MTL.png  metalness (grey)
      rig.json        piece centers and sizes, pivots, attachments, team pieces, triangles, textures
      preview_*.png   Blender renders at 35°, 55°, 80° and side (gitignored)
```

## Steps

1. **Build** (no Studio needed):
   ```
   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python-exit-code 1 -P assets/models/<unit>/build.py
   ```
   It models every piece in Roblox model space (studs, forward = −Z) with its origin at its joint pivot, fails if the triangle count is over the unit's budget, unwraps all pieces into one atlas, bakes color (camouflage, edge wear, ambient occlusion), team mask, roughness, metalness and normal (bevelled edges, grilles, tread) in Cycles, renders previews and exports the FBX with the textures embedded.
2. **Look at the previews** (`export/preview_*.png`) before importing.
3. **Import (your clicks)** in "FTGG Art": Import 3D → `export/<unit>.fbx`. Defaults are fine (Upload to Roblox, Import Only as a Model, Add to Workspace, Set Pivot to Scene Origin). The importer uploads the meshes and the four textures and builds the SurfaceAppearance itself (AlphaMode Overlay).
   - Known import behavior (Blender FBX → Roblox): **×100 scale** (read as centimeters) and **turned 180° about Y**. The rig step undoes both; nothing to set in the importer.
   - **Grey model after import:** the importer also attaches a `TexturePack` that Studio generates from the four maps. If one map fails to download during that (an HTTP 502 on a fresh upload), the pack stays broken for the session and every SurfaceAppearance using those maps draws grey, though the maps load (a Decal shows them). Scripts can't clear `TexturePack` (RobloxScript capability), and changing a map didn't recover it; **restarting Studio did**. It happened on 2 of the first 3 imports, so plan on it: **after an import, rig, save the place (save, not publish) and restart Studio** before judging the look.
  - **When a restart doesn't fix it, re-import.** The BAR Lancer stayed grey through two restarts (its metalness map failed with HTTP 502 at import). A new SurfaceAppearance made by script, even one with only the color map, drew grey too. The same color map drew on a Decal and as a `TextureID`. The Lancer mesh drew the Ravager's maps correctly. So the meshes are fine and the fault is the uploaded maps as SurfaceAppearance content. A plain re-import doesn't help: the importer recognizes identical files and reuses the broken uploads (same asset IDs). Instead, bump `lib.UPLOAD_REV` in the unit's `build.py` and rebuild. That changes one corner pixel of every map, so the next import uploads them anew. (A rebake isn't bit-identical anyway: the Lancer's rebuild also moved about 2% of the texels and may give the meshes new IDs; the look is unchanged.)
   - Record the uploaded IDs in `<unit>/roblox_assets.json` (meshes, the four maps, the model): the rigged model can be rebuilt from them without importing again.
4. **Rig** (`rig_model.luau` through `execute_luau`, with the unit's `rig.json`): `normalize(src, rig, 0.01, true)`, then `check` (sizes within 5 %, piece offsets within 0.05 studs) and `rig`: pieces into a Model named after the unit, pivot offsets cleared, `base` anchored and primary, one `Motor6D` per piece at the rig.json pivots, attachments (`muzzle`), collisions off, `TeamColor` tags, `RenderFidelity = Automatic`, `RootOffset` / `FootprintStuds` / `Triangles` attributes. Saved as `ReplicatedStorage.Models.<unit>`; the client uses it over the blockout (`Render/Models.luau`).
5. **Test** in "FTGG Art" on the Coastline terrain next to the part-built blockout: pitch 35°, 55°, 80° at close (40), normal (220) and far (450) zoom; frame time with 100 units (below).
6. **Commit** the scripts and `export/` (except previews); add the uploaded asset IDs to `rig.json`'s notes in the progress file.

Getting the models into the game place "For The Greater Good" is the client session's step.

## Budgets and texture memory

### The Lancer (first run)

| | Value | Guide 20.1 |
|---|---|---|
| Triangles | 3,016 (base 2,036, turret 608, barrel 372), level of detail automatic | 300–1,500 (raised to about 4,000 for this test, M-12) |
| Textures | one set of four 1024 × 1024 maps shared by the three pieces | one palette texture for all units |
| Instances | 3 MeshParts (blockout: 13 Parts) | — |

### Open Cloud route (2026-10-22)

With an Open Cloud API key (user-owned, Assets read and write, IP-restricted, read from the `ROBLOX_API_KEY` user environment variable and never printed), the import needs no clicks:

1. `python assets/models/tools/opencloud.py <export dir> <unit id> <creator user id>` uploads the five maps as Decals and the FBX as a Model (it arrives as a package with the MeshParts) and writes `export/opencloud.json`.
2. In "FTGG Art", `InsertService:LoadAsset(<model id>)` gives the MeshParts at x100 and turned 180° like the 3D Importer's, so `rig_model.luau` normalizes and checks them unchanged. `LoadAsset(<decal id>)` gives each Decal's image ID.
3. The rig step replaces the FBX's own SurfaceAppearance with one made from the Decal images (ALB, NOR, RGH, MTL; the EMI image as the emissive mask). On the first test the FBX's own maps drew grey (HTTP 502 on a fresh map, as importer uploads do until a restart), while the Decal images drew at once: **no Studio restart needed**.

Found on the first batch (ten units, 2026-10-22):
- A mesh bigger than about 20 studs comes in clamped: the ×100 import is capped at 2048 studs on its longest side, so the 22-stud vehicle plants normalize at 22 / 2048, not 0.01 (`OpenCloud.load`'s `scale` argument; the size check catches it).
- Now and then one fresh image fails in Studio with HTTP 502 and stays failed for the session. Re-uploading that image gives a new ID that loads: 2 of 50 images in the first batch.
- A new SurfaceAppearance combination takes Studio a minute to build its texture pack; until then the part draws plain grey. No restart is needed.
- A fresh image can also fail with `HttpError: NetFail` (4 of 6 units in the second batch). Like the HTTP 502s, Studio caches the failure until it restarts; after a restart every one of them drew. So after a batch: check the log for `NetFail` / `502`, and restart Studio once if any appear.

Limits (Roblox docs): one asset per request, up to 20 MB; images under 8000 × 8000; a Model upload is a package; no published per-minute limit for creating assets, limits apply per key owner and a 429 carries `x-ratelimit-reset` (the tool waits and retries); moderation still applies to each upload. One unit is six uploads (five maps and the FBX); the FBX's embedded maps are uploaded too but not used.

### Shared runner (2026-10-22)

`assets/models/tools/unit.py` holds the faction looks (the approved tanks' paints, specs and accents, M-15, M-18), the detail helpers (bolts, seams, rings) and the whole flow after the geometry: bake, previews framed on the unit's size, FBX with the emissive probe, `rig.json`. A unit's `build.py` only describes its pieces (`unit.PieceSpec(name, parent, pivot, build, details)`) and calls `unit.run(...)`. The structures use it (extractors, generators, solars, vehicle plants, Bulwark, Spike); the tanks and the four vehicles derived from them keep their own scripts.

### 100 units, render CPU time per frame

"FTGG Art", Edit mode, flat area, 100 Lancers in a 10 × 10 grid 12 studs apart, game camera pitch 55°, three runs of 6–8 s per case (run 2 in reverse order; run 3 after the Studio restart, with the textures drawing). Studio reports no GPU time, and its frame rate is throttled to about 15 fps when its window isn't focused, so frame time itself says nothing; `Stats.RenderCPUFrameTime` is the render thread's CPU work per frame either way.

| Scene | Close (40 studs), runs 1 / 2 / 3 | Normal (220), runs 1 / 2 / 3 |
|---|---|---|
| Empty | 4.1 / 3.3 / 4.0 ms | 4.3 / 3.3 / 4.3 ms |
| 100 blockouts | 5.4 / 3.9 / 6.0 ms | 6.0 / 3.5 / 4.6 ms |
| 100 meshed Lancers | 5.1 / 4.9 / 4.3 ms | 5.5 / 3.8 / 4.3 ms |

- Over the empty scene, 100 meshed Lancers add 0.0–1.6 ms of render CPU (0.0–0.3 ms with textures drawing) and 100 blockouts 0.3–1.9 ms: the meshes are no more expensive, and in run 3 cheaper. Three MeshParts per unit cost less CPU than thirteen Parts.
- `GraphicsTexture` memory stayed at 24 MB through run 3: the Lancer's set was already loaded by the test pair, so the per-unit cost isn't isolated here (estimate below).
- On the GPU, 100 meshed Lancers are about 300,000 triangles (blockouts about 40,000); automatic level of detail cuts that with distance. A desktop GPU doesn't notice either; phones are untested.
- **Not measured yet:** GPU time and real frame rate. They need a focused Studio window or, better, a live server on a phone and a low-end PC.

### 100 and 300 BAR tanks, render CPU time per frame (2026-10-22)

Same method as above, BAR Lancers and Ravagers alternating (M-18 rebuild, textures already loaded), on the open baseplate, grid 12 studs apart (10 × 10 and 15 × 20), pitch 55°. Two passes, the second in reverse order; `Stats.RenderCPUFrameTime` averaged over 3–5 s. The appearance hitch is the worst frame gap in the 1.5 s after the folder of units is parented (instance creation, textures warm).

| Scene | Close (40 studs), pass 1 / 2 | Normal (220), pass 1 / 2 | Appearance hitch, pass 1 / 2 |
|---|---|---|---|
| Empty | 4.7 / 5.9 ms | 5.4 / 4.8 ms | — |
| 100 blockouts | 4.5 / 5.5 ms | 4.9 / 6.1 ms | 66 / 50 ms |
| 100 BAR tanks | 4.8 / 3.9 ms | 4.5 / 4.3 ms | 21 / 32 ms |
| 300 blockouts | 4.1 / 4.4 ms | 4.2 / 4.4 ms | 125 / 102 ms |
| 300 BAR tanks | 4.4 / 4.0 ms | 4.1 / 4.0 ms | 56 / 46 ms |

- Run-to-run noise (about ±1 ms, the empty scene included) is bigger than any difference between the cases: 300 BAR tanks cost no measurable render CPU over the empty scene or over 300 blockouts.
- Creating and parenting the units hitches about half as long for meshes (3 MeshParts each) as for blockouts (13 Parts each): about 0.15–0.2 ms per BAR tank.
- **First appearance with cold textures** is extra: the first time a unit type's maps are drawn they load (review 2 measured a one-off 320 ms on the Lancer's first appearance). It can't be repeated once a session has loaded them; preloading each unit type's maps at match start (`ContentProvider:PreloadAsync` on a template) moves that cost out of the battle. The client stream's call.

### Texture memory across the roster

One unit set is four 1024² maps. Roblox doesn't document how it stores them on the GPU: compressed (about 1 byte per pixel for color and normal, 0.5 for the grey maps, plus a third for mip levels) it's about **4 MB per unit**; uncompressed RGBA it's about **22 MB**. "FTGG Art" reports 24–27 MB of `GraphicsTexture` with the Lancer, the terrain and the review parts loaded.

| Textures | Per unit | 30 unit types in a match | Whole roster (about 120 defs) |
|---|---|---|---|
| 1024 set each | 4–22 MB | 120–670 MB | 0.5–2.7 GB |
| 512 set each | 1–6 MB | 30–170 MB | 0.1–0.7 GB |
| Shared faction set (two 1024 sets) | — | 8–45 MB | 8–45 MB |

Only the unit types present in a match load, and Roblox lowers texture resolution on low-memory devices, but at 1024 per unit the upper end is too much for phones.

**Is 1024 needed?** At normal zoom (220 studs) the Lancer is about 40 pixels across on a 1080p screen; at the closest zoom (40 studs) about 200. The atlas gives the hull top about 250 texels, so 512 is enough for line units at every zoom, and 1024 only shows on hero units seen close.

**Shared faction sets:** a faction trim sheet (camouflage panels, armor plates, tracks, wheels, sensors, glass) that every unit's UVs map onto. Memory stays flat however big the roster gets, and the look is consistent. The costs: no per-unit baked ambient occlusion or edge wear (unless baked into vertex colors), the camouflage repeats, and modeling has to follow the sheet's layout. The team mask still works (alpha in the shared color map).

### Proposed budgets (to confirm on devices)

| Class | Examples | Triangles | Textures |
|---|---|---|---|
| Hero units | MBTs, command vehicles, capital ships, strategic bombers (6–8 per faction, few on screen) | up to 6,000 | unique 1024 set |
| Line units | light tanks, artillery, SAMs, scouts, workers, fighters, helicopters | up to 3,000 (the Lancer is the reference) | unique 512 set, or the shared faction set |
| Structures | turrets, factories, economy, sensors | up to 3,000 (footprint 1–2), 6,000 (footprint 3+) | shared faction set; unique 512 for landmarks |
| Wrecks | all | up to 1,000 | the unit's own set, darkened through `SurfaceAppearance.Color` |

Scene target: about 1 million triangles at normal zoom (for example 250 line units and 40 structures), to be checked on a phone. **Recommendation:** unique 512 sets for line units now (no change to the pipeline), 1024 for heroes, and a shared faction trim sheet for structures, which are many and static. Switch line units to the shared set if phones run short of memory.

## AI base mesh: options and licenses

| Generator | Commercial use of outputs | Fit |
|---|---|---|
| Studio's `generate_mesh` (Roblox Cube, hosted) | Made inside Roblox under Roblox's terms, for use on Roblox | Stays in Studio as up to 8 parts, no clean path into Blender |
| Roblox Cube 3D open weights | Research-only license (Cube3D Research-Only RAIL-MS): no commercial use | Not usable |
| Meshy | Free plan: CC BY 4.0, commercial with credit; paid plans: commercial, no credit | Props, references |
| Tripo | Paid plans: commercial; free-plan terms contradict each other on Tripo's own pages | Paid only |
| Microsoft TRELLIS / TRELLIS.2 | MIT (code and weights); hosted versions add their own terms | Needs a 16 GB+ GPU (this PC: 6 GB) or a host |
| Tencent Hunyuan3D 2.x | Not valid in the EU, UK or South Korea; above 1 million monthly users needs Tencent's permission | Avoid |

If generated bases are wanted for props or structures: Meshy on a paid plan, credited in `CREDITS.md`.

## Mesh manifest (M-23)

After every upload (or a status change): `python assets/models/tools/manifest.py`, then `lune run mesh_materials` (client tool, C-103: the SurfaceAppearances game scripts can't build themselves), then `lune run test_client Meshes` and `lune run test_client MeshMaterials`. Commit the mesh, `src/shared/Defs/Meshes/Registry.luau` and `place/MeshMaterials.model.json` together (rig.md section 7).

**A model that draws white** (no team color, no glow) after an Open Cloud upload: Studio couldn't build its SurfaceAppearance because a map failed (HTTP 502). The log says "Unable to generate ... Change a TextureId property to retry", but a retry with the same image fails again. Re-upload the failing maps as new Decals (`opencloud.upload`) and swap the new images in. Note them in the unit's `roblox_assets.json`. **Flat team color** is different: the color map is still loading, and it fixes itself within minutes. Rigging a pair a few minutes after its upload (bake the next pair meanwhile) avoids most of these. If a swapped map still leaves the model white after ten minutes (2026-10-23: three helicopters did), re-upload the whole unit with `opencloud.py` and rig it again: the meshes come back with the same IDs, the maps with new ones.

**Clamped imports:** Roblox clamps an Open Cloud model by its **largest single mesh** (2048 studs at the ×100 import), not the whole scene. So the rig scale is that mesh's longest side / 2048. For example, the Citadel's base is 23.53 studs (its barrel reaching further doesn't count), and the vehicle plants use 22 / 2048.

## Wrecks (M-24)

`FTGG_WRECK=1 blender -b --factory-startup --python-exit-code 1 -P assets/models/<id>/build.py` builds the wreck into `export_wreck/` as `<id>_wreck` (`lib.WRECK`, `unit.wreck_look`). Then:
1. upload it: `python assets/models/tools/opencloud.py assets/models/<id>/export_wreck <id>_wreck 11846985184` (same clamp rule);
2. rig it with `Batch.run` in "FTGG Art" (`ReplicatedStorage.ModelReview.<id>_wreck_bar`);
3. `record_assets.py` writes it under `wreck` in the unit's `roblox_assets.json`;
4. then `manifest.py` as above.
