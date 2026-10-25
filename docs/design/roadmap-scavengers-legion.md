# Roadmap: Scavengers (PvE) and Legion (third faction)

From the user's playtest feedback of 2026-10-26. Neither is built in this round: this file records what the user asked for and how it would fit the current game, so the work can be planned when the user schedules it. Owner of the plan: sim-A.

## Scavengers: an AI faction for a PvE mode

**The user's brief:** aliens with highly advanced technology. They lay waste to the land, capture technology, and are spawned by Spawn Beacons to attack. Their units are the Order, Chaos (and later Legion) units upgraded to their standard: more weapons, stats and mechanics. They also have an ancient super weapon that rains down destruction, Starfall. Primary colour: dark purple.

**How it would fit:**

| Part | Approach | Who |
|---|---|---|
| Mode | A match mode `PVE` (MatchConfig `mode`): every human on one ally team against the Scavengers' ally team, which never counts as a player (no Commander rule; the match ends when the humans' last Commander dies, or when every Spawn Beacon is destroyed and the waves stop) | A (rules), D (room setting) |
| Units | A def overlay instead of a full roster: `scv_<id>` defs derived at load from each Order/Chaos def (`Defs.build`), with a scaled health and damage, an extra weapon slot where the model has room, dark-purple team colour, and a `scavenger` flag. New models only for the beacon, Starfall and a few heroes | A (defs), C (overlay look: emissive purple trim on existing meshes, then hero models), B (icons) |
| Spawn Beacons | Structures placed by the map or the mode (a `layers.beacons` list), each spawning waves on a timer that grows with match time and with how many humans there are; destroying one stops its waves | A |
| Capture technology | Scavenger "harvester" units turn wrecks and destroyed structures they reach into Scavenger copies (the reverse of resurrect, S-168), so a lost base feeds them | A |
| Starfall | A super weapon on a long timer: a rain of meteor shells over a large area, warned to every player like a nuke launch (S-48 LAUNCH_WARNING) | A (sim), B (VFX, warning UI) |
| AI | Not the skirmish AI: a wave director (spawn budget per minute, target the nearest or the weakest base, escalate) | A |
| Difficulty | Easy / Normal / Hard / Brutal: wave budget, unit stat scaling, Starfall timer | A, D |

**Open questions for the user:** which maps (all, or PvE maps with beacons placed); do the waves ever stop (survival) or end when the beacons fall (assault); can Scavengers expand (build their own beacons) on Hard.

## Legion: a third faction

**The user's description (for the record):** cheap, easily mass-produced units with weaker stats overall, backed up by stronger, specialised ones to anchor the forces and apply pressure. Auto-producing drone hubs; napalm and cluster-munition artillery; precision railguns that overpenetrate killed units and double as anti-air. Strong early map control through cheapness, skirmishers and raiders, but its T1 falters in direct engagements with heavier troops. Rewards micromanagement (its napalm can burn its own units). Cheap drones from defence structures and mobile units cover flanks and disrupt attacks. Air: no traditional bomber; cheap kamikaze drones and rocket gunships; in T2 a heat-ray bomber, very effective against land units and ships. Land: packs of nimble skirmishers with specialists for smashing formations and defences. Primary colour: green (#2fd900).

**What it would need (when scheduled):**

- **Faction plumbing:** `faction = "legion"` everywhere a faction is checked (S-174 made it per player, so the sim side is mostly ready): MatchConfig.FACTIONS, the pre-game's FACTION command (value 2), a Legion Commander, the AI's faction prefix (`leg_`), the lobby's faction picker, team colours (Legion green would be reserved, not one of the cold / warm shades).
- **New mechanics:** drone hubs (structures and units that build and keep a few drones on a leash, refilled for supply), napalm (ground fire areas that burn anything in them, own units included, for a few seconds), cluster munitions (a shell that splits into bomblets), overpenetrating railguns (a hit-ray that continues past a killed target, S-115's ray with a damage budget), kamikaze drones (an aircraft whose attack is its death blast, S-178).
- **Roster:** about 40 units for parity with Order and Chaos at T1/T2 (C models, B icons, D Codex roles).
- **Balance:** the faction pass (`lune run factions`) and fairness reports for three-faction matchups.

**Suggested order when the user schedules it:** the faction plumbing and the Commander first (playable mirror matches), then T1 with drone hubs and napalm, then T2 with railguns and the heat-ray bomber.
