# Map pipeline

How a map is made (S-196, the user: "follow Beyond All Reason's pipeline for map design"). It follows BAR's mapping guide (beyondallreason.info, "Mapping: File Structure & Prerequisites"). A map is a set of painted image layers and a settings file, compiled into the game's data. Generated maps (`mapgen:`, MapGen) and the older hand-coded maps (Normandy, The Canyon, The Plains) still work as before. New named maps go through this pipeline.

## 1. The source folder: `assets/maps/<name>/source/`

| File | BAR's | Size | What it holds |
|---|---|---|---|
| `height.png` | heightmap (16-bit PNG, 64 × size + 1) | 64 × size + 1 pixels a side | Grey or 16-bit grey. Black = `height.min`, white = `height.max` studs. |
| `type.png` | typemap (8-bit) | 16 × size | Ground type per pixel: the greys `mapinfo.types` names (GRASS, SAND, ROCK, ROAD). |
| `metal.png` | metalmap (8-bit RGB, red dots) | 16 × size | A red dot per metal spot; full red = `metalValue`, dimmer red less. |
| `minimap.png` | minimap | 1024 × 1024 | The overview: the lobby's preview, the minimap. |
| `features.luau` | featureplacer (mapconfig) | | The map's trees and rocks (S-197): { kind, u, v, value? } as fractions; with point symmetry, one side (the compiler adds the twins). Trees reclaim into power, rocks into supply; rocks block their cell. `lune run map_features` writes a first list. |
| `mapinfo.luau` | mapinfo.lua | | Settings: name, description, `size` (BAR units), `cells` (our cells a side), `height` {min, max}, `waterLevel`, `wind`, `types`, `metalValue`, `symmetry`, `starts` (fractions: u from the west edge, v from the north), optional `sideSplits`. |

`size` is BAR's map size in map units (512 elmos). Our maps run at The Canyon's scale, about 13 cells per BAR unit. A 24 × 24 BAR map is 320 cells (2,560 studs), so `cells` is set in mapinfo.

The painted texture (BAR's "diffuse", 512 × size pixels) isn't kept in the repository; keep it with the map's other source files.

## 2. Tools

- **`lune run map_derive <name> <texture.png> [height.png]`**: for a map that starts from a painted texture.
  - It writes `type.png`, `metal.png` and `minimap.png`, plus `height.png` as 8-bit grey when a height map is given.
  - **Type:** green paint, and the mesas' yellow tops, become grass. Steep ground and dark stone on high ground become rock. The remaining grey (beaches, paths, the sea floor) becomes sand.
  - **Metal:** the texture's cyan crystals become metal spots.
  - The outputs are sources from then on: fix them by hand, the way BAR's are painted.
- **`lune run map_compile <name>`**: BAR's map compiler in our form. It writes `src/shared/Grid/Maps/<name>.luau`, which `Shared/Grid/CompiledMap` loads, both in Lune and in Roblox.
  - **Heights:** box-averaged per cell. Cells below `waterLevel` are sea, so crater lakes come out of the height map by themselves.
  - **Types:** each cell's nearest pixel.
  - **Metal:** one deposit per red dot; spots closer than 3 cells merge.
  - **Point symmetry** (`symmetry = "point"`): twin cells match. Heights are averaged; types, deposits and starts come from the south-west half and are mirrored.
  - **Starts:** each snaps to the nearest open ground: dry, not rock, wheeled units can stand there, with a 5 × 5 clearing.
  - **Checks:** it exits 1 if a start is in water or on rock, or if a land move class can't reach every start from start 1. It notes dry deposits that land units can't reach (on mesa tops).
- Register the map in `MapRegistry` (a small module that builds it from the compiled data, like `Shared/Grid/SupremeStrait`). Add its spec. Models-C bakes its ground mesh from the compiled layers (`lune run export_ground map:<name>`, S-192).

## 3. Checklist (after BAR's "Final Map Pre-release Checklist")

- Starts on open ground, each with a metal cluster (2–3 spots close by). Every start reachable on land.
- Fair: symmetric, or the sides' metal and space equal.
- Chokepoints at least 3 cells wide (guide 5.5).
- Water for naval maps deep enough for ships (6 studs; subs 12).
- The size class and features read right in the lobby (`MapRegistry.details`).
- The ground baked and approved (S-192).

## 4. Maps made this way

- **Supreme Strait** (`map:supreme_strait`, S-195, S-196): rebuilt from BAR's preview images.
  - `height.png` is its 1537-pixel height map; `type.png`, `metal.png` and `minimap.png` come from its dry texture (`map_derive`).
  - Heights run −6 to 83.25 studs, with the water at 8.
  - 90 metal spots, BAR's own (its metal map, sent by the user): the six big ones on the strait at value 4; 12 under water, 4 on mesa tops.
  - 398 trees and 170 rocks (`map_features`, seed 197).
  - The 16 starts are the user's 8v8 spawn points.
  - If it isn't close enough to the original, the user may send BAR's map file to convert instead.
