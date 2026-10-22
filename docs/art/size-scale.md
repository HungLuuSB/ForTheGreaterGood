# Size scale (proposal, 2026-10-23)

**Status: proposal, waiting for the sim stream.** Footprints and unit sizes are sim rules (blocking, pathing, collision, build range), so nothing is rescaled until the sim agrees (models stream, M-26). The user's direction: size shows tech level. T1 can stay modest; T2 is clearly larger; T3 is the largest of all. The same holds for units.

## Reference: the Lancer (T1 tank)

| | Value |
|---|---|
| Footprint | 1 cell (8 × 8 studs); collision radius 3.6 studs (`RADIUS_PER_FOOTPRINT` 3.6) |
| Hull | 8.3 long × 6.0 wide (12.1 with the barrel), 3.7 tall |
| "Tank length" below | 8 studs (one cell) |

## Structures

| Tier | Category | Footprint (cells) | Width (studs) | Height (studs) | Visual bulk |
|---|---|---|---|---|---|
| T1 | Economy: extractor, solar, wind, generator, storage, converter, tidal | **2** | 16 | 4–8 (wind: a thin mast to 18) | Modest, low. The **generator is the bulkiest**: a full-height reactor block with stacks. Solar is a low panel field. Storage is a low tank or vault. |
| T1 | Factories: vehicle plant, airfield, shipyard | **4–5** | 32–40 (4–5 tank lengths) | 9–12, the **tallest T1 buildings** | A hall or hangar, an open assembly bay with a visible build pad, a crane or gantry. |
| T1 | Defenses | **1–2** | 8–16 | 4–6 | Light turrets, SAM sites and torpedo launchers at 1. The gun turrets (Bulwark, Spike) at 2. |
| T1 | Sensors, utility | 1 (rearm pads 3) | 8 | radar towers 12, others 3–6 | Thin and tall (radar) or small (sonar buoys, jammers). |
| T2 | Economy: fusion, advanced extractor | **3–4** | 24–32 | 10–16 | Reactor housings, cooling stacks, pipes and transformers; visibly more advanced than the T1 generator. |
| T2 | Factories (advanced plants, airfields, shipyards) | **6** | 48 | 14–18 | Multiple bays, gantries, conveyors, a second crane; clearly bigger than T1. |
| T2 | Defenses | **2–3** | 16–24 | 8–14 | Clearly bigger than T1: heavier mounts, ammo feeds, sensor heads. Beam towers, heavy turrets, shield generators, SAM, artillery and coastal batteries at 3; flak at 2. |
| T2 | Sensors | 2–3 | 16–24 | long-range radar 20+, others 10–15 | A long-range radar is a landmark. Fire-control, pinpointers and advanced jammers at 2; sonar stations at 3. |
| T3 | Everything T3 (Citadel, silos) | **6–8** | 48–64 | 14–24 | The biggest silhouettes on the map. |

## Units

| Tier | Role | Footprint | Size (studs, length × width × height) | Scale vs the T1 of the same role |
|---|---|---|---|---|
| T0 | Commanders | 1 | ~10 × 7, mast to 8–9 | 1.2× the Lancer: reads unique but keeps T1 pathing |
| T1 | Tanks, builders, wheeled | 1 | Lancer 8.3 × 6 × 3.7; wheeled ~7 × 5 | 1× |
| T2 | Heavy tanks (Paladin, Warden, Juggernaut, Minotaur), heavy artillery (Cyclops) | **2** | 11–12.5 × 8–9 × 5 | 1.4–1.5× |
| T2 | Light / support (radar, jammer, AA trucks, Judgement, Hydra, T2 builders, amphibious) | 1 | 9–10 × 6.5 × ~5 | 1.3× (fits one cell) |
| T2 | Aircraft | 1 | span 12–14 | 1.3–1.5× |
| T2 | Naval: capital ships | 3 (already) | 29–30 long | already ~2.7×, keep |
| T2 | Naval: small (Reaver, Harbormaster, Siren) | 1 | ~14 long | 1.3× |
| T3 | Units (none in the roster yet) | 2–3 | ≥ 16 long | ≥ 2× |

## Footprint changes this would make

Current → proposed. Everything not listed keeps its footprint.

| Defs | Now | Proposed |
|---|---|---|
| T1 economy: `ord_/chs_extractor`, `_solar`, `_windmill`, `_generator`, `_depot`, `_converter`, `_tidal` (14) | 1 | 2 |
| T1 factories: `ord_vehplant`, `chs_vehplant` | 3 | 4 |
| T1 factories: airfields, shipyards | 5 | 5 (keep) |
| T1 gun turrets: `ord_bulwark`, `chs_spike` | 1 | 2 |
| T2 fusion: `ord_fusion`, `chs_fusion` | 3 | 4 |
| T2 advanced extractors: `ord_advextractor`, `chs_advextractor` | 1 | 3 |
| T2 factories: `ord_/chs_advvehplant`, `_advairfield`, `_advshipyard` (6) | 5 | 6 |
| T2 beam towers: `ord_radiance`, `chs_inferno` | 2 | 3 |
| T2 shield generators: `ord_phalanx`, `chs_carapace` | 2 | 3 |
| T2 heavy turrets: `ord_bastion`, `chs_maw` | 1 | 3 |
| T2 flak: `ord_lumen`, `chs_hailstorm` | 1 | 2 |
| T2 advanced jammers: `ord_veilspire`, `chs_blackout` | 1 | 2 |
| T3: `ord_citadel` | 3 | 7 |
| T3 silos: `ord_reckoning`, `chs_ragnarok` | 3 | 6 |
| T2 heavy tanks: `ord_paladin`, `ord_warden`, `chs_juggernaut` | 1 | 2 (`chs_minotaur`, `chs_cyclops` are already 2) |

Kept: T1 airfields and shipyards (5), rearm pads (3); T1 light defenses, SAM sites, torpedo launchers, floating turrets and walls (1); T1 sensors (1); T2 SAM (Aegis, Wyvern 3), artillery (Edict, Cataclysm 3), coastal batteries (3), long-range radars (3), fire-control radars and pinpointers (2), sonar stations (3); every other unit.

## Questions for the sim

- **Extractors on deposits:** 2 cells for T1 and 3 for T2. Does a deposit spot allow that, or should extractors keep 1 and only look bigger (a visual skirt over the neighbouring cells, not blocking)?
- **Walls** (`ord_barrier`) stay 1 for wall lines.
- **Fp-2 units** need 2-cell clearance in pathing (`requiredClearance`). Are 5 heavy T2 tanks at fp 2 acceptable for the flow fields and the stress budget? If not: keep fp 1 and draw them 1.4× anyway (a bigger model, the same collision).
- **Build range and spacing:** builders reach a target's edge (`halfSize`), so bigger structures are easier to reach. Do base-building spacing or the AI's build placement need retuning?
- **Factory exits:** the spawn goes one cell beyond `halfSize`, so it moves out with the new footprints. The models keep the exit at model −Z and the `buildpad` anchor moves with each redesign (rig.md 8).

## After the sim agrees

The models are **redesigned, not scaled**: each structure gets more of what it does at its new size (rig.md 8 anchors move with them):
- factories: assembly bays, gantries, cranes, conveyors, vents, loading ramps, a visible build pad;
- generators and fusion: reactor housings, cooling stacks, pipes, cabling, transformers;
- defenses: heavier mounts, ammo feeds, sensors.

T2 and T3 get visibly more advanced construction. Big readable shapes come first, small detail second, checked at 55° and 220 studs, in the BAR style, with team panels on top surfaces and the glow rules. Budgets: T1 structures up to 6,000 triangles, T2 up to 8,000, T3 up to 10,000. Each gets the 55° and 220 shots, plus one lineup per tier with a Lancer for scale, as "review".
