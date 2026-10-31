# Reserved units: BAR's 65 files no Commander can reach

Part 3 of the BAR roster program (`docs/design/bar-roster-plan.md`), approved by the user on 2026-10-31.
- **Draft only:** no defs, no models, no icons. A unit here becomes real only when the user picks an event or mode for it; it then goes through the batch pipeline like any other.
- Names follow S-225's rule: each says what the unit does. Order names draw on law, virtue, the church and the heavens; Chaos names on beasts, plague and ruin. Every name is checked against all of BAR's names (the README's 442, the 65 below included) and our 207.
- Source: the README's "Not covered" list in `assets/reference/bar-units/` (look only).

## The modes and events they fit

| Mode or event | What it is | What it needs first |
|---|---|---|
| **Experimental (T4) mode** | A lobby option. Each faction gets an experimental tier: four plants and four engineers that build beyond the gantry, plus a longer-reach Construction Turret | A T4 tech level in the tech tree; experimental units to fill the plants (from the gantry list and new ones); D's lobby option |
| **Drone warfare** | Carriers launch short-lived drones that fight and return | The drone mechanic (bar-roster-plan §1.2): spawned units bound to a carrier, a leash range, a respawn timer, no wreck |
| **Doomsday tide** | A naval event: each side may build one nuclear-missile submarine | A submerged nuke launcher (our silo's stockpile, S-48, on a SUB) |
| **Coastal assault** | A scenario where the sea side has heavy assault subs, bombardment ships and anti-ship turrets on the shore | Shore placement for the turrets (placement "either" exists); the units |
| **Island defence** | Floating defences on open water for sea maps | The floating shield needs our shields (S-79) on water |
| **Fortified economy** | A mode where extractors defend themselves | A structure that both mines and fires (an extractor with a weapon) and EMP (batch 1) |
| **Campaign or scenario only** | Units kept for single scenarios | Nothing beyond its own def |
| **Record only** | Old versions and duplicates; nothing to build | Nothing |

## The units

### Experimental (T4) mode

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `armhalab` | Experimental Bot Lab | **Pantheon** (Order) | T4 tier; experimental bots |
| `armhavp` | Experimental Vehicle Plant | **Grand Arsenal** (Order) | T4 tier; experimental vehicles |
| `armhaap` + `armhaapuw` | Experimental Aircraft Plant, on land or under water (merged, placement "either") | **Skyforge** (Order) | T4 tier; experimental aircraft |
| `armhasy` | Experimental Shipyard | **Admiralty** (Order) | T4 tier; experimental ships |
| `armhack` | Experimental combat engineer, bot | **Artificer** (Order) | Builds the T4 plants |
| `armhacv` | Experimental combat engineer, vehicle | **Demiurge** (Order) | Builds the T4 plants |
| `armhaca` | Experimental construction aircraft | **Ascender** (Order) | Builds the T4 plants |
| `armhacs` | Experimental engineer ship | **Shipwright** (Order) | Builds the T4 shipyard |
| `armnanotct2` + `armnanotc2plat` | Advanced Construction Turret, land or water (merged) | **Steward** (Order) | A larger assist radius than the Construction Turret (S-211) |
| `corhalab` | Experimental Bot Lab | **Spawning Pit** (Chaos) | T4 tier; experimental bots |
| `corhavp` | Experimental Vehicle Plant | **Siegeworks** (Chaos) | T4 tier; experimental vehicles |
| `corhaap` + `corhaapuw` | Experimental Aircraft Plant, land or water (merged) | **Wyrmnest** (Chaos) | T4 tier; experimental aircraft |
| `corhasy` | Experimental Shipyard | **Bonedock** (Chaos) | T4 tier; experimental ships |
| `corhack` | Experimental combat engineer, bot | **Grafter** (Chaos) | Builds the T4 plants |
| `corhacv` | Experimental combat engineer, vehicle | **Forgehand** (Chaos) | Builds the T4 plants |
| `corhaca` | Experimental construction aircraft | **Ossifrage** (Chaos) | Builds the T4 plants |
| `corhacs` | Experimental engineer ship | **Salvager** (Chaos) | Builds the T4 shipyard |
| `cornanotct2` + `cornanotc2plat` | Advanced Construction Turret, land or water (merged) | **Taskmaster** (Chaos) | As the Steward |
| `leghaap`, `leghaca` | Legion's experimental aircraft plant and engineer | — | Out of scope: Legion isn't one of our factions |

### Drone warfare

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `armdronecarry` | Drone carrier (ship) | **Chantry** (Order) | Drones |
| `armdrone` | Its attack drone | **Cherub** (Order) | Drones: spawned, leashed, no wreck |
| `armtrident` | Depth-charge drone carrier (ship) | **Cloister** (Order) | Drones; depth charges against subs |
| `armtdrone` | Its depth-charge drone | **Plumb** (Order) | As above |
| `cordronecarry` | Drone carrier (ship) | **Broodmother** (Chaos) | Drones |
| `cordrone` | Its attack drone | **Mite** (Chaos) | Drones |
| `corsentinel` | Depth-charge drone carrier (ship) | **Spawnbarge** (Chaos) | Drones; depth charges |
| `cortdrone` | Its depth-charge drone | **Bloodfly** (Chaos) | As above |
| `armcarry` | Aircraft carrier with an anti-nuke | already our **Sanctuary** (`ord_sanctuary`) | — |
| `corcarry` | Aircraft carrier with an anti-nuke | already our **Leviathan** (`chs_leviathan`) | — |

### Doomsday tide and coastal assault (naval events)

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `armseadragon` | Nuclear-missile submarine | **Dies Irae** (Order) | A submerged nuke launcher; the anti-nukes (Ladon, Providence) already cover it |
| `cordesolator` | Nuclear-missile submarine | **Pestilence** (Chaos) | As above |
| `armexcalibur` | Coastal assault submarine | **Lancet** (Order) | Surfaces to fire at shore targets (a SUB that fires at land) |
| `coronager` | Coastal assault submarine | **Lurker** (Chaos) | As above |
| `corprince` | Long-range heavy bombardment ship | **Tyrant** (Chaos) | Nothing new: a heavy naval artillery def |
| `corsiegebreaker` | Heavy long-range destroyer | **Breachmaw** (Chaos) | Nothing new |
| `armanavaldefturret` | Shore turret: tachyon and gauss against ships | **Breakwater** (Order) | Placement "either" (exists) |
| `armnavaldefturret` | Shore turret: twin gauss cannons against ships | **Portcullis** (Order) | As above |
| `coranavaldefturret` | Shore turret: blaster and plasma against ships | **Grindmaw** (Chaos) | As above |
| `cornavaldefturret` | Shore turret: heavy plasma against ships | **Gullet** (Chaos) | As above |
| `armtorps` | Torpedo ship | **Tribune** (Order) | Nothing new (torpedoes exist) |

### Island defence

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `armfgate` | Floating shield | **Nimbus** (Order) | Shields (S-79) on water |
| `corfgate` | Floating shield | **Barnacle** (Chaos) | As above |
| `armfrock` | Floating anti-air missile battery | **Skyward** (Order) | Nothing new |
| `corfrock` | Floating anti-air missile battery | **Spitter** (Chaos) | Nothing new |
| `armgplat` | Light plasma gun platform | **Picket** (Order) | Nothing new |
| `corgplat` | Light plasma gun platform | **Spur** (Chaos) | Nothing new |
| `armsonar` | Sonar station | **Auditor** (Order) | Nothing new: sonar exists on ships; this is the structure |
| `corsonar` | Sonar station | **Harkener** (Chaos) | As above |

### Fortified economy

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `armshockwave` | Advanced extractor with an EMP turret | **Tocsin** (Order) | EMP (batch 1); an extractor with a weapon |

### Campaign or scenario only

| BAR id | What it is | Proposed name | Needs |
|---|---|---|---|
| `corphantom` | Amphibious stealth scout | **Skulker** (Chaos) | Stealth (exists). A candidate for batch 2 if the user wants it buildable |
| `corseal` | Medium amphibious tank | **Gharial** (Chaos) | Nothing new (AMPHIB). A candidate for batch 1's amphibious set |
| `corprinter` + `corvac` | Armored field engineer that repairs and reclaims while moving (merged) | **Junkmonger** (Chaos) | Work while moving (our builders stop to work) |

### Record only (old versions and duplicates)

| BAR id | What it is | Note |
|---|---|---|
| `armdroneold` | An old attack drone | Replaced by `armdrone` (Cherub) |
| `cordroneold` | An old attack drone | Replaced by `cordrone` (Mite) |
| `armprowl` | "Prowler", a test file | No description in BAR |
| `corvacct` | A test file | No description in BAR |
| `armsfig2` | Heavy area seaplane fighter | A variant of a batch 3 seaplane fighter; taken up there if needed |
| `corsfig2` | Heavy area seaplane fighter | As above |
| `cormine4` | Medium mine | A mine size; batch 5 decides the mine sizes |

## Count

65 BAR files, 49 new names:

| Group | Files | New names |
|---|---|---|
| Experimental (T4) | 24 (2 of them Legion's, out of scope; land and water plants merged) | 18 |
| Drone warfare | 10 (2 already ours: Sanctuary, Leviathan) | 8 |
| Naval events | 11 | 11 |
| Island defence | 8 | 8 |
| Fortified economy | 1 | 1 |
| Campaign or scenario | 4 (`corprinter` and `corvac` merged) | 3 |
| Record only | 7 | 0 |
