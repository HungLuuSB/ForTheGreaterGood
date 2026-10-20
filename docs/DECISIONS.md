# Decisions log

Decisions made while working unattended. Each entry gives the date, the decision, the alternatives and the reason. Everything here is meant to be easy to change. Overrule any of them and I'll update the code, the guide and this file together.

## Summary

_Written when the unattended session ends. See `docs/PROGRESS.md` for the full status._

---

## D1 — Unit modules require `Defs/Templates`, not `Defs` (2026-10-20)

- **Decision:** `Templates.luau` holds the templates and `extend()`. Unit modules use `local Templates = require("../Templates")` and `Templates.extend(Templates.TankT1, {...})`. `Defs.luau` re-exports `Defs.extend` and `Defs.Templates`.
- **Alternatives:**
  - The guide's literal `require("../Defs")`, which is a require cycle because Defs loads the registry and the registry loads the units.
  - Pure-data modules with an `extends = "TankT1"` field, resolved by the loader.
  - Lazy-loading the registry inside Defs.
- **Why:** this keeps the guide's `extend(template, overrides)` style with no cycle and no lazy tricks. Guide 4.2's example is updated to match.

## D2 — Defs are registered by hand in `Defs/Registry.luau` (2026-10-20)

- **Decision:** one module lists every unit and weapon module, keyed by file name. The loader checks each key against the def's `id`.
- **Alternatives:**
  - Enumerate folder children: Instances in Roblox, `@lune/fs` in Lune. That gives two code paths and breaks the "no runtime-specific code outside Util adapters" rule.
  - A Lune script that generates the registry.
- **Why:** it's the only portable option. A generator script can come later if the list gets long.

## D3 — Unknown def fields are errors (2026-10-20)

- **Decision:** any field not in the unit or weapon spec fails validation.
- **Alternatives:** warn only, or ignore.
- **Why:** a typo such as `maxspeed` would otherwise silently fall back to the template value. That is exactly the kind of bug that should "fail loudly in Studio, not mid-match" (guide 4.1). A new field means adding one line to the spec in `Defs.luau`.

## D4 — Separate 1-based index spaces for units and weapons (2026-10-20)

- **Decision:** `unit.index` runs 1..N over units sorted by id, and `weapon.index` runs 1..M over weapons sorted by id.
- **Alternatives:** one shared index space, or 0-based.
- **Why:** packets name the kind of def by context (`defIndex` in BUILD is always a unit, `weaponDefIndex` in SPAWN_PROJ is always a weapon). 1-based matches Luau arrays, and 0 is already reserved on the wire (Schema).

## D5 — Defs hash: FNV-1a 32-bit over a canonical serialization (2026-10-20)

- **Decision:** `Util/Hash.value` walks the built defs with sorted keys and hashes numbers by their IEEE-754 bytes (`string.pack("<d")`).
- **Alternatives:**
  - SHA-256: needs a pure-Luau implementation and is slower, with no security need here.
  - Hashing a formatted string: printf output can differ between platforms.
  - A 64-bit hash.
- **Why:** it's deterministic on every runtime and cheap. 32 bits is plenty to detect a stale client. If accidental collisions ever become a worry, two independent FNV passes give 64 bits.

## D6 — Wrecks deferred; Lancer and Ravager have no `wreck` yet (2026-10-20)

- **Decision:** `wreck` is optional and validated only if present. There are no `neu_wreck_*` defs yet.
- **Alternatives:** add minimal feature defs now.
- **Why:** wreck defs need a feature schema (supply value, footprint, model) that belongs with M2 (deaths and wrecks).

## D7 — Lancer and Ravager stats are placeholders (2026-10-20)

- **Decision:**
  - Both are T1 tracked tanks with armor class ARMORED.
  - Lancer: 1100 HP, cannon with 180 range and 0.5° spread.
  - Ravager: 1300 HP, cheaper, cannon with 160 range, 1.2° spread and more damage.
- **Alternatives:** the LIGHT armor class for light tanks.
- **Why:** they match the faction doctrines in guide 2.1. Balance happens in M8.

## D8 — Cell indices are 0-based, `index = cz * cellsX + cx` (2026-10-20)

- **Decision:** cells are addressed by 0-based `(cx, cz)` or by a 0-based row-major index. Layer buffers use the same index (`offset = index * bytesPerCell`).
- **Alternatives:** 1-based indices to match Luau arrays.
- **Why:** the index is the `u16` on the wire (0..65535 for 256×256), and buffers are 0-based. Converting once at the edges would invite off-by-one bugs.

## D9 — `Grid.encode` clamps out-of-map positions to the edge (2026-10-20)

- **Decision:** a world position outside the map encodes as the nearest edge cell (offset 0 or 255).
- **Alternatives:** raise an error.
- **Why:** the wire must never carry an invalid cell, and a unit sitting exactly on the far edge (x == maxX) is legitimate floating-point noise. Keeping units inside the map is Movement's job; that's tested there.

## D10 — Offsets truncate (floor); decode returns the step's low corner (2026-10-20)

- **Decision:** `off = floor(frac * 256)` and `decode` uses the guide's formula unchanged, so the error is in `[0, 1/32)` stud, always toward the cell origin.
- **Alternatives:** round to nearest (error ≤ 1/64, but 255.5 rounds to 256 and needs carry into the next cell), or decode at the step center.
- **Why:** it's simplest and never carries. 1/32 stud is far below anything visible.

## D11 — Map layers live in `Grid/Layers.luau`; test maps in `Grid/TestMap.luau` (2026-10-20)

- **Decision:**
  - `Layers` owns the terrain inputs (`height`, `waterDepth`: i16 in 0.25-stud steps, rounded to nearest). Derived layers (slope, passMask, clearance) are added by the passability builder.
  - `TestMap.generate` is 3-octave value noise (lattice spacings 32/8/4 cells) seeded by `Prng`.
  - Water fills everything below `seaLevel`.
  - `TestMap.build` makes hand-built maps from a per-cell callback.
- **Alternatives:** Perlin or simplex noise, or loading the guide's `MapData/` format.
- **Why:** value noise is enough for hills and lakes, and it's cheap and deterministic. Real maps come from the Studio bake in M1+.

## D12 — Debug images: PPM plus PNG written from Lune (2026-10-20)

- **Decision:** `.lune/lib/Ppm.luau` writes binary PPM and also PNG (zlib via `@lune/serde`, CRC-32 in Luau), so images open directly on Windows. Debug scripts are `.lune/debug_*.luau` and write to `debug_out/`.
- **Alternatives:** PPM only.
- **Why:** PPM isn't viewable without extra software, and PNG takes about 30 extra lines.
