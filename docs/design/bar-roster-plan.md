# The BAR roster program: plan (draft for the user's approval)

Owner: sim-A (lead and integrator). Streams: clients-B, models-C, lobby-D, 2d-E.
Status: **draft, nothing applied.** Every proposal below waits for the user's decision; the "Decisions needed" list at the end collects them.

**Reference:** `assets/reference/bar-units/` (README, `armada.md`, `cortex.md`, `pictures/`). It is git-ignored (`.gitignore`: `assets/reference/`).
- The stats are game data (BAR's GPL-2.0 code): fine to compare and to start drafts from.
- The pictures and BAR's models are CC BY-NC-ND: look only. Nothing is traced, copied or committed from them, and no stream works from them as a texture or mesh source.
- Armada → Order, Cortex → Chaos. Every new unit gets our own name, checked against all 442 BAR names and our 207.
- Standing rules hold: uploads and publishing only with the user's approval; no balance reports unless the user says "run the balance checkpoint".

---

## Part 1. Audit of what exists

Method: our 207 defs (dumped from `sim.defs`) against their BAR counterparts (README, "Our units and their BAR counterparts"). Each value is divided by BAR's value × the median factor (README, "Conversion factors"). So ×1.00 is "where the median unit sits", ×0.2 is "five times cheaper than the median conversion".

### 1.1 Stat outliers

**Ours far cheaper or weaker:**

| Unit | Against BAR's counterpart (× the median) | Deliberate? | Proposal |
|---|---|---|---|
| Juggernaut `chs_juggernaut` (T3) | supply ×0.18, power ×0.15, health ×0.26; DPS ×0.52, range ×1.62 | Partly. T3 is compressed for our match length (S-209, S-216): the Titan sits at ×0.34. The problem is the pair: the Juggernaut costs 1.1× the Titan (3,600 / 3,200 supply) but does 2.2× its DPS (1,830 / 843). | **Change.** Keep T3 compressed, but price the Juggernaut like BAR does relative to the Titan (≈1.5×): supply 5,400, power 78,000, build time 180,000, health 54,000. Or keep its price and cut its DPS to ≈1,200. Your pick. |
| Edict `ord_edict`, Cataclysm `chs_cataclysm` | cost ×0.19, range ×0.22–0.33 | Yes. They are T2 artillery emplacements at a third of BAR's long-range plasma cannon range, and priced for it. The counterpart match is the loose one. | **Keep.** Re-label their counterpart "artillery emplacement (FTGG-only)". BAR's true map-reach guns (Basilica, Basilisk) and the rapid-fire Ragnarok / Calamity arrive as new strategic units in batch 5. |
| Phalanx `ord_phalanx`, Carapace `chs_carapace` (shields) | cost ×0.13–0.19, health ×0.6–0.85 | Yes. Our domes are small (radius 120 / 80) and were tuned to hold under focused fire (S-79, S-150). BAR's are much larger. | **Keep for now.** The AI builds one per base (S-101); watch the next playtest for shield spam. If it shows, double the cost (Phalanx 800 / 10,000). |
| Bulwark `chs_bulwark` (T2 beam tower) | cost ×0.20, health ×0.30, DPS ×0.31 | The cost is (T2 towers compressed like the Radiance, ×0.23). The health is not: BAR's Bulwark is the tougher of the two beam towers, ours is the weaker (2,600 against the Radiance's 3,200). | **Change health only:** 2,600 → 4,800 (the Radiance's factor). |
| Radiance `ord_radiance` | cost ×0.23, health ×0.56, DPS ×0.35 | Yes (S-96: one heavy hit every 9 s, 700 power a shot). | Keep. |
| Cyclops `chs_cyclops` | cost ×0.20, health ×0.46, DPS ×0.39 | Yes. A structure-only siege mortar (S-75), a different unit from BAR's Tremor. | Keep. Re-label its counterpart "FTGG-only". |
| Talos `chs_talos` (and Gauntlet `ord_gauntlet`) | cost ×0.24–0.28, DPS ×1.6–1.8 | Partly. The pair was designed together (S-157), and S-179 doubled the Talos's health. Cheap DPS for their price. | **Watch**, no change now. If the playtest shows T1 lobbing-gun walls, raise both to supply 330 / power 2,800. |
| Dragon `chs_dragon` (flying fortress) | cost ×0.26–0.39, health ×0.56, DPS ×1.56 | No. A playtest unit (S-181) that came in cheap for its punch. | **Change:** supply 900 → 1,600, power 16,000 → 28,000, build time 30,000 → 50,000. Health and weapons stay. |
| Wyvern `chs_wyvern`, Aegis `ord_aegis` (T2 long-range SAMs) | cost ×0.27–0.29 | No (placeholders, "stats to balance in M8"). BAR prices these high so they can't blanket the map. | **Change:** both ×1.8: Wyvern 540 / 6,800 / 15,000, Aegis 580 / 7,600 / 16,000. |

**Ours far tougher or dearer:**

| Unit | Against BAR's counterpart | Deliberate? | Proposal |
|---|---|---|---|
| Glint `ord_glint` | health ×6.8, cost ×4.1–4.3 | Yes. A laser scout bot (S-181), not a Tick: the counterpart match is wrong. | Keep. Re-label its counterpart "role: scout bot". |
| Falcon, Harpy, Archon, Manticore (fighters) | health ×2.6–4.1, cost ×1.7–4.0 | Yes. Every fighter sits there (S-62's faction pass): our air is fewer, tougher, dearer and slower to trade. | Keep. |
| Phantom `ord_phantom` (bomber) | supply ×3.1, health ×1.4 | Yes, the same air rule. | Keep. |
| Herald `ord_herald`, Jackal `chs_jackal` (scouts) | health ×3.3–3.5, cost ×2.5–3.6, DPS ×2.3–2.8 | Yes. Our scouts are meant to live long enough to scout (S-62). | Keep. Batch 1 brings the cheap fast raiders BAR uses them as (Courser / Gnat below). |
| Watchtower, Eye, Beacon (radar towers) | health ×3.0–4.1 | Yes. They stand at the front, and S-179 halved the T1 radar range. | Keep. |
| Vigil `ord_vigil` (and Thorn `chs_thorn`) | health ×2.9–4.2, cost ×1.6–2.4 | Yes. T1 anti-air towers hold out against our dearer aircraft. | Keep. |

**Also out of line** (not on your list; for your information, no proposal unless you want one):
- Naval guns: Dominion and Kraken have range ×2.3–2.6 with DPS ×0.3, and Breaker and Rampart have DPS ×0.22–0.26. Our ships trade range for damage.
- Seraph and Gorgon (mobile SAMs): range ×3–4, health ×0.33. Ours are long-reach radar SAMs, by design.
- Titan: cost ×0.34, health ×0.46. The T3 compression above.
- Commanders show DPS ×150: a parsing artefact, from the D-Gun counting as a weapon.

### 1.2 Mechanics BAR has and we don't

"Cost" is the work to build it: S = a few days in one module; M = sim plus protocol plus client; L = across streams with map or pathing work. "Units" counts BAR's no-counterpart units (README) that need it, by batch.

| Mechanic | What it is | Cost | Value | Units that need it |
|---|---|---|---|---|
| **Cloak** | Invisible to sight beyond a short decloak distance while it pays power upkeep; revealed by close enemies and by the anti-radar pulse | M: sensors, an upkeep drain, protocol, a client shader | High: 21 units | B1: Gremlin. B2: Ghost, Spectre (spies), Sharpshooter, Skuttle, decoy Commanders. B5: mines, Twilight (cloaked extractor), cloakable fusion, Ferret, Rattlesnake, Beholder. |
| **EMP / paralyze** | Damage that fills a paralysis bar instead of health; a full bar stuns the unit for a while | M: Damage, a state bit, protocol, a client effect | Medium: 5 units, strong counterplay | B1: Thor. B2: Webber. B3: Stiletto, Shuriken. B5: Paralyzer (EMP missile). |
| **Mines and minelayers** | Cloaked, stealthy one-shot structures that explode when an enemy is close; minelayers build them in the field | S once cloak exists: a proximity trigger on a structure | Medium: 8 mines + 2 layers | B5 (with the mines): Groundhog, Trapper and the 8 mines. **Proposal: move the two minelayers from batch 1 to batch 5,** so batch 1 doesn't carry mines. |
| **Geothermal** | Power plants that only stand on geo vents | L: a new map layer (vents in the map compiler and `ground.json`), placement, models | Medium: 10 units | B5: geo T1 / T2 (land and offshore merged), Prude, Cerberus-style geo battery. Needs the maps stream: vents on our maps first. |
| **Crawling bombs (kamikaze)** | A walker that runs at enemies and detonates | S: our self-destruct (S-194) plus an "explode on contact" order | Medium: 2 units | B2: Tumbleweed, Bedbug. |
| **All-terrain spiders** | Walkers that climb any slope | S–M: a new move class `SPIDER` (no slope limit) in Passability and the flow fields | Medium: 5 units | B2: Recluse, Webber, Termite; B2 T3: Vanguard, Karganeth. |
| **Seaplanes** | Aircraft that land and idle on water, built at a floating platform | M: air landing on water surfaces, a water-placed airfield | Medium: 10 units + platform | B3: 5 per faction plus the seaplane platform. |
| **Hovercraft** | Cross land and water at the same speed; slope-limited | S: the `HOVER` class and its pathing exist (Passability `hover` surface); it needs a test with real units and the hover factory | High: 13 units + platform | B1 (all of them). |
| **Spy bots and capture** | Cloaked bots; capture takes an enemy unit over time | Capture is M (a capture-progress state like reclaim, then an owner change); spies need cloak | Low–medium | B2: Ghost, Spectre; the decoy Commanders capture in BAR. **Proposal: spies without capture** (cloaked scouts with a self-destruct EMP); capture waits for a mode that wants it. |
| **Anti-radar pulse (Juno)** | A missile that wipes radar, jammers, mines and stealth in an area | S–M: an area effect on sensors | Medium: 2 units, a counter to cloak and mines | B5: one per faction. |
| **Decoy Commander and decoy fusion** | Look like the real thing even in sight | S: our `spoof` (S-109) extended to sight, not only radar | Low–medium: 4 units | B2 (decoy Commanders), B5 (decoy fusion; Chaos's Advanced Exploiter decoy). |
| **Perimeter camera** | A tiny cloaked structure that only gives sight | S once cloak exists | Low: 2 units | B5 (Beholder). |
| **Pop-up turrets** | Hidden and armored until an enemy comes close, then open and fire | S: our switch-off shell (S-96) made automatic | Medium: 5 units | B5: Dragon's Claw / Maw, Ferret, Rattlesnake, Persecutor. |
| **Veterancy (XP)** | Units gain health and reload from damage dealt | S in the sim, but it touches every balance number | Low for now | None need it. **Proposal: not now.** |
| **Autoheal** | Units slowly heal when idle | S | Medium for flow: fewer dead-but-alive stragglers | None need it, but BAR has it on almost everything. **Proposal: a global idle autoheal at 1% of max health per second after 10 s out of combat**, its own S-number, playtest first. |
| **Drones** | Carriers spawn short-lived attack drones | M–L | Reserved units only (part 3) | None in the buildable roster. |
| **Sonar stealth** | Hidden from sonar | S: we have radar stealth (`STEALTH`, `EW`) | Low: 4 units | B2 spies, B5 naval mines. |

### 1.3 Models

- **No model changes from the audit.** None of the stat or name proposals changes a unit's role or silhouette.
- **One model change from part 4:** wrecks gain a scrap-heap state (generic heap meshes from C, below).
- The Goliath was re-modelled in S-224 (done).

### 1.4 Names

The README lists **64** of our names that BAR also uses; **29** of them are a different unit in BAR (you counted about 50 and 34). One of the 29 is the retired `ord_bulwark`, so **28 renames to decide**. Only the display name changes: ids stay (S-157), so nothing breaks across streams. D updates the Codex, B the tooltips. Every proposed name below is checked against all 442 BAR unit names and our 207.

| Our unit (id) | Today | It is | Proposed name |
|---|---|---|---|
| `chs_augur` | Augur | Pinpointer (radar accuracy) | **Haruspex** |
| `chs_banshee` | Banshee | Jammer aircraft | **Dirge** |
| `chs_barracuda` | Barracuda | Corvette | **Piranha** |
| `chs_basilisk` | Basilisk | Point defence against missiles | **Flytrap** |
| `chs_behemoth` | Behemoth | Strategic bomber | **Hecatomb** |
| `chs_centurion` | Centurion | Heavy laser bot | **Ogre** |
| `chs_cerberus` | Cerberus | Anti-nuke | **Ladon** |
| `chs_condor` | Condor | Advanced air worker | **Carrion** |
| `chs_corsair` | Corsair | Destroyer | **Cutthroat** |
| `chs_cyclops` | Cyclops | Siege mortar | **Mauler** |
| `chs_gorgon` | Gorgon | Mobile radar SAM | **Medusa** |
| `chs_hailstorm` | Hailstorm | Flak tower | **Sleet** |
| `chs_hornet` | Hornet | Mobile IR SAM | **Gadfly** |
| `chs_kraken` | Kraken | Cruiser | **Charybdis** |
| `chs_lamprey` | Lamprey | Submarine | **Hagfish** |
| `chs_manticore` | Manticore | T2 fighter | **Strix** |
| `chs_ragnarok` | Ragnarok | Nuke silo | **Doomsday** |
| `chs_riptide` | Riptide | Floating turret | **Whirlpool** |
| `chs_shroud` | Shroud | Mobile jammer | **Murk** |
| `chs_watcher` | Watcher | Mobile radar | **Gazer** |
| `ord_arbiter` | Arbiter | Fire-control radar | **Assessor** |
| `ord_archangel` | Archangel | AWACS | **Firmament** |
| `ord_citadel` | Citadel | Fortress | **Stronghold** |
| `ord_oracle` | Oracle | Mobile radar | **Scryer** |
| `ord_paladin` | Paladin | Main battle tank | **Vindicator** |
| `ord_phantom` | Phantom | Stealth bomber | **Eclipse** |
| `ord_veil` | Veil | Mobile jammer | **Mantle** |
| `ord_warden` | Warden | Deployable gun | **Steadfast** |

You can take all, some or none; a name you don't like gets a second pick.

---

## Part 2. Adding the rest of BAR's buildable units

### 2.1 Batches and the pipeline

| Batch | Units (README count) | Defs after merging variants | Mechanics it needs first |
|---|---|---|---|
| 1 | Vehicles and hovercraft: 31 | 29 + 2 hover factories (minelayers move to batch 5) | Hovercraft in play; **cloak** (Gremlin); **EMP** (Thor) |
| 2 | Bots, the gantry walkers included: 43 | about 40 (the two decoy Commanders become one per faction) | All-terrain spiders, crawling bombs, spies (cloak), decoys in sight |
| 3 | Air and seaplanes: 21 | 21 + one seaplane platform per faction | Seaplanes; EMP (Stiletto, Shuriken) |
| 4 | Naval: 25 | about 23 | Sonar stealth; the resurrect ships (`canresurrect` exists, S-168) |
| 5 | Structures: 77 | about 50: naval storage, converter, Construction Turret, extractor and fusion merged into one def each with `placement = "either"` (as the hover factory in batch 1), land and offshore geo merged | Geothermal (a map layer), mines (with the two minelayers from batch 1), Juno, pop-up turrets, the perimeter camera, decoy fusion |

**Each batch:**
1. **sim-A** picks the list and the merges (a), builds the mechanics (b) and drafts names and defs from the README's "FTGG suggested" values (c). The defs stay in a draft branch, not on main.
2. **Approval 1 (the user):** the list, the names and the first-draft numbers (d).
3. Requests go out through each stream's "Requests" section in its progress file, one batch at a time:
   - **C:** blockouts, then meshes, then wrecks. Each step goes to the user for approval, and uploads only with it.
   - **E:** unit icons and build-menu pictures. E renders from C's approved models; nothing is drawn from BAR's pictures.
   - **B:** rigs, piece scripts, effects and UI for the new mechanics (cloak shimmer, EMP stun, hover wake).
   - **D:** Codex entries and counterpart rows.
4. **sim-A:** AI use (factory mixes, the counter table in `AI/Counters`, hover and amphibious routing), tests (a spec per mechanic, and every new def builds, moves, fights and dies) and docs.
5. **One integrated merge per batch:** defs, then C's models, then E's pictures, then B's client and D's Codex, in that order through `integrate.sh`, each with the full checks. A def can land before its model: the blockout and the icon fallback cover it (S-224's order).
6. **Playtest proposal** after batch 1, and after every two batches from then.

While C models batch *n*, sim-A drafts batch *n + 1*'s defs (still a draft). **One batch in flight per session.**

### 2.2 Batch 1: vehicles and hovercraft (for your approval)

29 units + 2 factories. First-draft numbers are the README's "FTGG suggested" values; they get tuned in the def drafts.

**Order (Armada):**

| BAR | Role | Tier | Built by (ours) | Proposed name | First draft: supply / power / health / speed |
|---|---|---|---|---|---|
| `armflash` Blitz | Fast assault tank | T1 | Vehicle Plant | **Courser** | 76 / 510 / 680 / 31 |
| `armjanus` Janus | Twin rocket tank | T1 | Vehicle Plant | **Gemini** | 170 / 1,500 / 960 / 17 |
| `armpincer` Pincer | Light amphibious tank | T1 | Vehicle Plant | **Wader** | 140 / 1,100 / 1,300 / 20 |
| `armbeaver` Beaver | Amphibious constructor | T1 | Vehicle Plant | **Pontifex** | 100 / 1,800 / 960 / 13 |
| `armconsul` Consul | Combat engineer | T2 | Advanced Vehicle Plant | **Magistrate** | 170 / 2,400 / 1,000 / 24 |
| `armgremlin` Gremlin | Cloaked tank | T2 | Advanced Vehicle Plant | **Whisper** | 160 / 2,100 / 990 / 22 |
| `armlatnk` Jaguar | Lightning tank (and an AA missile) | T2 | Advanced Vehicle Plant | **Fulgur** | 230 / 3,600 / 990 / 28 |
| `armmart` Mauser | Mobile artillery | T2 | Advanced Vehicle Plant | **Mandate** | 220 / 2,800 / 1,000 / 19 |
| `armmanni` Starlight | Mobile tachyon beam | T2 | Advanced Vehicle Plant | **Luminary** | 830 / 11,000 / 2,600 / 13 |
| `armthor` Thor | Lightning and EMP tank | T3 | Experimental Gantry | **Thunderer** | 6,200 / 140,000 / 52,000 / 17 (T3 to be compressed like the Titan) |
| `armch` | Hover constructor | T1 | Hover Dock | **Skimwright** | 140 / 1,500 / 1,300 / 21 |
| `armanac` Crocodile | Hover tank | T1 | Hover Dock | **Skimmer** | 190 / 1,400 / 1,400 / 22 |
| `armmh` Possum | Hover rocket artillery | T1 | Hover Dock | **Volley** | 120 / 1,700 / 500 / 20 |
| `armsh` Seeker | Fast hover raider | T1 | Hover Dock | **Dart** | 59 / 710 / 270 / 35 |
| `armah` Sweeper | Hover anti-air | T1 | Hover Dock | **Halcyon** | 160 / 2,600 / 1,000 / 27 |
| `armlun` Lunkhead | Heavy hovertank | T3 | Experimental Gantry | **Tempest** | 790 / 13,000 / 5,000 / 16 |
| `armhp` + `armfhp` | Hovercraft factory, land or water | T1 | Order builders | **Hover Dock** | 460 / 1,100 / 3,100 / — |

**Chaos (Cortex):**

| BAR | Role | Tier | Built by (ours) | Proposed name | First draft: supply / power / health / speed |
|---|---|---|---|---|---|
| `corlevlr` Pounder | Riot tank | T1 | Vehicle Foundry | **Cleaver** | 150 / 1,500 / 1,300 / 12 |
| `corgarp` Garpike | Light amphibious tank | T1 | Vehicle Foundry | **Mudskipper** | 150 / 1,500 / 1,300 / 18 |
| `cormuskrat` Muskrat | Amphibious constructor | T1 | Vehicle Foundry | **Dredger** | 120 / 2,000 / 1,000 / 13 |
| `corban` Banisher | Heavy missile tank | T2 | Advanced Foundry | **Hellfire** | 690 / 13,000 / 2,300 / 17 |
| `corparrow` Poison Arrow | Very heavy amphibious tank | T2 | Advanced Foundry | **Grendel** | 720 / 12,000 / 5,900 / 16 |
| `cormart` Quaker | Mobile artillery | T2 | Advanced Foundry | **Hurler** | 280 / 2,500 / 1,100 / 18 |
| `corch` | Hover constructor | T1 | Skim Yard | **Drifter** | 130 / 1,700 / 1,400 / 19 |
| `corsnap` Cayman | Hover tank | T1 | Skim Yard | **Snapjaw** | 210 / 1,800 / 1,600 / 21 |
| `cormh` Mangonel | Hover rocket artillery | T1 | Skim Yard | **Sling** | 140 / 1,900 / 510 / 20 |
| `corsh` Goon | Fast hover raider | T1 | Skim Yard | **Gnat** | 52 / 850 / 240 / 34 |
| `corah` Birdeater | Hover anti-air | T1 | Skim Yard | **Skua** | 170 / 2,700 / 1,000 / 27 |
| `corhal` Halberd | Assault hovertank, heavy laser | T1 | Skim Yard | **Glaive** | 440 / 7,400 / 4,100 / 14 |
| `corsok` Cataphract | Heavy laser hovertank | T3 | Experimental Gantry | **Typhon** | 660 / 11,000 / 3,900 / 14 |
| `corhp` + `corfhp` | Hovercraft factory, land or water | T1 | Chaos builders | **Skim Yard** | 460 / 1,100 / 3,500 / — |

**Moved to batch 5 (proposal):** `armmlv` Groundhog and `cormlv` Trapper, the minelayers (names reserved: **Sapper** and **Burrower**). They only make sense with the mines.

**Notes on batch 1:**
- **The asymmetry is BAR's:** Order gets 10 vehicles to Chaos's 6. Chaos has no counterpart to the cloaked tank, the lightning tank, the tachyon tank or Thor; Order has none to Banisher's heavy missiles or Grendel. That's in keeping with S-75 (faction-only units).
- **Amphibious units** (Wader, Mudskipper, Pontifex, Dredger, Grendel) use the existing `AMPHIB` class. BAR also builds them in an Amphibious Complex (batch 5). Here our vehicle plants build them, as BAR's do too.
- **T3 hovers and Thor** come from the existing gantries. Their numbers are compressed like the Titan's (S-209, S-216) in the def drafts, not taken at BAR's ×0.69.
- **Mechanics first:** a hover pathing check with real hover units (land, shore, water, slopes), cloak (Whisper), and EMP (Thunderer's two EMP lasers).
- **AI:** the hover factory on water maps (Coastline, Supreme Strait), amphibious tanks on mixed maps, the new roles in `AI/Counters` (the riot tank as `heavy` against light, the rocket hovers as `artillery`, the fast raiders as `raider`).

### 2.3 Later batches (outline; each list comes for approval when its turn comes)

- **Batch 2, bots (43):**
  - T1: Centurion, Pawn, Rocketeer, Aggravator.
  - T2: advanced constructors, both anti-air bots, Butler / Twitcher, the decoy Commanders, Compass / Augur, the spies, Gunslinger, Hound, Platypus / Duck, Recluse, Sharpshooter, Smuggler, Sprinter, Tumbleweed / Bedbug, Webber, Welder / Fiend / Commando, Sheldon, Skuttle, Termite.
  - T3 walkers from the gantry: Marauder, Razorback, Vanguard, Behemoth, Catapult, Demon, Karganeth, Shiva.
- **Batch 3, air (21):**
  - Blink / Finch scouts;
  - Osprey / Hephaestus heavy transports;
  - Cormorant, Hornet, Roughneck, Stiletto, Shuriken, Angler, Condor (the AWACS);
  - the seaplanes and their platform.
- **Batch 4, naval (25):** frigates, the resurrect ships, Skater / Herring, the T2 subs and battleships, Epoch / Black Hydra, the antiship carriers' pairs, the naval jammer, Longbow / Messenger, Voyager / Pathfinder.
- **Batch 5, structures (77, about 50 defs):**
  - economy (geo, naval variants merged, Twilight, Exploiter, cloakable fusion, Prude, Cerberus);
  - defences (mines, pop-ups, Juno, Anemone / Jellyfish, Chainsaw, Eradicator, Moray, Paralyzer, the strategic guns);
  - sensors and utility (Beholder, walls, Shark's Teeth, decoy fusion, Tracer / Nemesis, naval Pinpointer).

---

## Part 3. The 65 units no Commander can reach (reserved for events and modes)

A draft doc, **`docs/design/reserved-units.md`**, with no defs and no models. It is written right after this plan's approval, in parallel with batch 1's drafts. For each of the 65 it gives:
- the BAR id;
- what the unit is;
- a proposed name;
- the event or mode it fits;
- what it would need.

The groups it will cover:
- **Experimental T4 mode:** the experimental labs, constructors and plants of both factions (`armhalab`, `armhavp`, `armhaap`, `armhasy`, `armhaca` … and the Cortex set), plus `armnanotct2` / `cornanotct2`.
- **Drone carriers:** Nexus / Disperser, Trident / Sentinel, and their attack and depth-charge drones. They need the drone mechanic (1.2).
- **Naval event units:**
  - Seadragon / Desolator, nuclear subs (a "doomsday tide" event);
  - Excalibur / Onager, coastal assault subs;
  - Black Prince and Siegebreaker;
  - the naval defence turrets (Liquifier, Cauteriser, Orthrus, Cyclops).
- **Variants and old versions,** for the record only: `armdroneold`, `armsfig2`, `corsfig2`, `cormine4`, `corvacct`, `armprowl`.
- **Already mapped:** `armcarry` and `corcarry` are our Sanctuary and Leviathan. `corphantom` (an amphibious stealth scout) is a candidate for batch 2 if you want it.

---

## Part 4. New behaviour: wrecks take damage and wear down to scrap

### 4.1 Rules (proposed)

- **Wreck health:** 0.54 × the unit's max health. That is BAR's ratio: across 260 BAR units, `featuredefs.dead.damage` ÷ unit health has a median of 0.54.
- **Resources follow health:** current = full × health fraction.
  - Full is today's `WRECK_SUPPLY_FRACTION` 0.5 of the unit's supply.
  - Reclaim takes resources, so it lowers health in step: reclaim and damage wear the same bar. Reclaim always gives the current amount.
  - Resurrect's refill (S-168) raises it back.
- **Damage:**
  - Splash from every explosion with an area of effect damages wrecks inside it, with the same edge falloff as units.
  - A direct hit counts when a shell or bomb lands inside a wreck's footprint.
  - Beams and hitscan shots hurt a wreck only when it is their target (attack-ground on it).
  - Units never pick wrecks as targets.
- **Scrap heap:** below **40%** of its health, the wreck becomes a heap.
  - 40% matches BAR: a BAR heap holds a median 0.40 of its wreck's metal (IQR 0.40–0.42), and 0.50 of its health. **Please confirm 40%.**
  - A heap can't be resurrected (a RESURRECT order on it is refused, and an ongoing resurrect stops), only reclaimed.
  - Its model swaps to a scrap pile.
- **Gone:** a heap at 0 health disappears, leaving no resources.
- **Map features** (trees and rocks, S-197) are not affected: they keep today's behaviour.

### 4.2 Sim work (sim-A)

- `Combat`: `wreckHealth` and `wreckMaxHealth`, and a `wreckHeap` flag. Supply is derived from health (one state, no drift). Hash and replay updated.
- `Damage` / `Ballistics`: splash and impact on wrecks through the contact grid, after the unit pass.
- `Build`: reclaim lowers health; resurrect refuses heaps; the heap switch.
- **Protocol 45:**
  - WRECK carries a heap bit;
  - WRECK_STATE adds health u8 (0..255) and the heap flag;
  - a new WRECK_HIT event (wreckId, impact point) for sparks, sent only to viewers who see it.
- **Replays:** the state is part of the sim hash, so old replays from before protocol 45 are refused as today.
- **AI:**
  - Smart Reclaim and the helpers (S-183, 7.5) take heaps and low-health wrecks first: they're cheap, and about to vanish.
  - Resurrect skips heaps.
  - The Construction Turret's auto-pick (S-211) does the same.
- **Tests:** wreck health from the unit; splash and direct hits; supply follows health; the heap switch at 40%; heaps refuse resurrect; 0 health removes it; reclaim lowers health; protocol round trip; replay determinism.

### 4.3 Requests (sent after this plan's approval)

- **C:** generic scrap-heap meshes: a pile of scattered metal bars in **4 sizes by footprint** (1, 2, 3, 4+), faction-neutral, our own design. Uploads only with your approval.
- **B:**
  - the wreck → heap swap, with a short spark and dust burst;
  - sparks where a wreck is hit (WRECK_HIT);
  - the current reclaim value in the wreck tooltip;
  - Resurrect greyed out on heaps, and on the cursor.
- **E:** a scrap / heap mark for the tooltip and the reclaim cursor, if B needs one.
- **D:** a Codex note on wrecks and heaps (resources fall with damage; heaps can't be resurrected).

---

## Orchestration

### Order of work

1. **Your decisions on this plan** (list below).
2. **Applied right after:**
   - the approved stat changes and renames as one sim commit (S-225), each with its decision entry. D (Codex) and B (tooltips) follow the renames; ids don't change.
   - `reserved-units.md` (part 3).
3. **Wrecks (part 4)** come before batch 1. Every new unit's wreck then follows the new rules from the start, and C makes the heap meshes once.
4. **Batch 1:**
   - mechanics: hover check, cloak, EMP;
   - defs: a draft, sent for your approval;
   - then requests to C, E, B and D;
   - then one integrated merge;
   - then a playtest proposal.
5. Batches 2–5 the same way, the next batch's defs drafted while C models the current one.

### Merge sequence for each batch (through `integrate.sh`, one at a time)

1. sim (mechanics and defs, with tests);
2. C (blockouts, then meshes and wrecks);
3. E (icons and pictures);
4. B (rigs, piece scripts, effects, UI);
5. D (Codex).

Any stream whose checks depend on another's (like S-224's lobby test) lands after it. The failure goes in "Integration notes" in `docs/progress/sim.md`.

### Files: who owns what

| Files | Owner |
|---|---|
| Defs (`src/shared/Defs/Units`, `Weapons`), the sim, the protocol, the AI | sim-A |
| Blockouts (`src/shared/Defs/Blockouts`), meshes, `assets/models`, `place/MeshMaterials` | C |
| Client (`src/client`), IconAtlas, piece scripts, effects | B |
| Codex (`src/lobby`) | D |
| 2D (`assets/2d`, the icon and picture sheets) | E |

No stream edits another's files; changes go as requests.

### Reporting

- **Per batch:** a section in `docs/progress/sim.md` with the list, the state of each stream and the merges.
- **Approvals:** every point that needs yours is sent to you as it comes up (names, numbers, models, uploads, playtests). Nothing waits silently.

## Decisions needed now

1. **Stats (1.1):**
   - the Juggernaut (raise its price, or cut its DPS);
   - Bulwark's health → 4,800;
   - the Dragon's price;
   - the Wyvern and Aegis price ×1.8;
   - keep the rest.
2. **Mechanics (1.2):**
   - cloak and EMP in batch 1;
   - the minelayers moved to batch 5;
   - spies without capture;
   - no veterancy;
   - a global idle autoheal, yes or no.
3. **Renames (1.4):** all, some or none of the 28.
4. **Batch 1 list and names (2.2).**
5. **Wrecks (4.1):** the 40% heap threshold, and the rules as written.
