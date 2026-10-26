# Skirmish AI guideline

How the skirmish AI thinks, what it reacts to, and how each level plays. The code is `src/server/Sim/AI/Skirmish.luau` (D90); the decisions behind it are S-17, S-31, S-57, S-76, S-92, S-97, S-101, S-105, S-110, S-187 in `docs/decisions/sim.md`. This guide describes the code as of S-191 (2026-10-26). When the AI changes, update it in the same change.

## 1. Ground rules: it plays fair

- **It knows only what its team knows.** It reads its ally team's sensors (sight, radar, sonar), its own units and economy, and the map's start spots. Enemy unit types are known only for units in sight and remembered structures (ghosts), never for radar blips.
- **It acts only through commands**, the same ones a player sends. So its games replay exactly, and it can't cheat on build times, costs or unit caps.
- **Its only randomness** is its own seeded random stream (the match seed and its player number), used for the production mix. The same match seed gives the same game.
- **In the pre-game** (choose your start), it waits until the humans have picked, or the pick time is over, then takes the best spot left and readies.

## 2. How it thinks: the loop

Every think (2 s on easy, 1.3 s on normal, 0.7 s on hard), it runs the same three jobs.

### 2.1 Builders: the base

In this order of need:

1. A **factory** first (Vehicle Plant / Foundry), facing the enemy.
2. **Generators** when power runs short (a stall in the last 5 s), placed in a tidy block behind the base: rows of 4, 24 studs apart. They're planned for what its factories, builders and missile refills draw.
3. **Extractors** on the nearest free deposits: home first, then expansions.
4. A **radar tower** once the plant and two extractors stand.
5. An **IR SAM site** when enemy aircraft come near home.
6. More factories as supply piles up: a second plant at 600 supply, the **advanced plant** at 900 supply (400 for the tech role), an **airfield**, and a **shipyard** on a sea map once the base is established. A bot lab for the levels and roles that use bots.
7. Otherwise its builders **help** a factory frame or a factory.

Easy builds only items 1–3 and 7: one plant, no radar, anti-air or further factories.

The **Commander stays home**: losing it ends the match under Command Ends.

### 2.2 Factories: what it builds

Each factory keeps a few items queued (1 on easy, 2 on normal and hard):

- **Vehicle plant:** workers until it has enough (2 on easy; otherwise 3, Chaos 4), then, above easy:
  - anti-air trucks: one per two enemy aircraft its team knows, at most 4;
  - one mobile radar;
  - one scout at a time, a new one at most every 2 minutes;
  - then tanks, with about one artillery piece in four (easy: one in seven).
- **Advanced plant:**
  - one T2 builder (Architect / Forgemaster) once 600 supply is stored;
  - a mobile anti-nuke if it knows of an enemy silo;
  - one fire-control radar;
  - a mobile jammer (Chaos);
  - then MLRS and main battle tanks half and half.
- **Bot lab:**
  - anti-air bots when more than 2 enemy aircraft are known;
  - two helper bots (Lazarus / Graverobber);
  - then scout bots and the light combat bot (Mace / Thug).
- **Advanced bot lab:** the heavy bot: Fatboy (Order) or Centurion (Chaos).

### 2.3 Army: waves

- New units gather at a **rally point** in front of the base, at least 600 studs from any other side's rally point.
- A **wave** leaves when the army at home is worth the wave's value. Value is supply cost plus power cost / 10; one wave "unit" is 300, about a T1 tank. So Chaos's cheaper units make the same wave with more of them. Each wave is bigger than the last.
- Before leaving, normal and hard also want the wave to **outweigh the known defence** at its target: 1.5 times the armed units and structures, turrets included, its team knows within 450 studs. Until then it **masses**. An army of half the unit cap (or 150 units) goes anyway.
- The wave **attack-moves** at the nearest known enemy: structures and the Commander first, or the enemy start if it knows nothing. It re-targets every 5 s.
  - Artillery follows the lead tank instead of stopping at its own long range.
  - Radar and fire-control vehicles go with it, so artillery can fire on radar contacts.
- Waves of **12+ front units split in two lanes**, so half comes round a flank (all non-easy levels since S-187).
- **Kiting** (not easy): artillery that an enemy gets within half its range backs off 100 studs, then rejoins.

### 2.4 Tech (normal and up)

Once the advanced plant stands and 600 supply is stored, its T2 builder:

1. Upgrades its own extractors to advanced ones, nearest home first, skipping any with known enemies near.
2. Then builds, in order:
   - a **shield generator** over the base;
   - **2 Pinpointers** behind it;
   - the **T2 defences**: a heavy turret toward the enemy, a missile battery behind it, a flak tower once enemy aircraft are known, a beam tower;
   - an **anti-nuke** over the base, plus a second once an enemy silo is known.
3. Hard only:
   - Order hard, rich: a **Citadel** toward the enemy;
   - any hard level, with supply storage 90% full: a **nuke silo** behind the base, which fires at the best known target at most once a minute.

## 3. How it reacts

| It sees | It does | Levels |
|---|---|---|
| Power stalling | builds generators (planned for its draw, plus one spare) | all |
| Missile refills stalling power | stops queuing army units until they're done | all |
| Enemy aircraft near home | builds an IR SAM site; anti-air trucks, 1 per 2 known aircraft (≤4); half its mobile SAMs stay home for a minute | normal, hard |
| More than 2 enemy aircraft known | its bot labs add anti-air bots | bot users |
| Known enemy aircraft | its airfield builds fighters | levels and roles with an airfield |
| Enemies inside its home (260 studs) | everyone at home fights them | all |
| An enemy wave (3+ ground units) within ~570 studs of home | **recalls the whole army home**; no new wave for 20 s | normal; Order on every level above easy |
| Its wave out in the field meets enemy forces worth 1.3× its own | **falls back** to the rally point; the next wave waits until the army is worth 1.2× what it fled, and none leaves for 20 s | normal, hard |
| 3+ known enemy turrets | more artillery (+20%); Chaos builds the Tzar more often | all |
| 3+ known enemy artillery pieces | fast raiders and scout bots among its tanks | all |
| A known enemy nuke silo | a mobile anti-nuke for the army, a second anti-nuke over the base | normal, hard |
| A deposit with known armed enemies within 300 studs (contested) | its worker waits for an escort of 2+ army units | Chaos above easy |
| A far deposit (over 160 studs from home) | escorts the worker with 3 army units, and guards the far extractors with turrets | hard |
| An ally's wave just left | joins it within 10 s, if its own army is worth half a wave | team AIs above easy |
| An ally's base is under attack | sends half its home army there | team AIs above easy |
| A builder can't reach its site for 20 s | gives up, avoids that site for 3 min | all |

## 4. The levels

### Easy: for a new player

**Personality:** slow, small and predictable. It builds an economy but stays small enough that a beginner can learn on it.

- Thinks every 2 s. 2 workers, 1 item queued per factory, at most 1 army unit every 20 s, an army of at most 8.
- At most 6 extractors, one plant: no radar, no anti-air, no tech, no airfield or shipyard, no kiting.
- **No attack before 8 minutes**, then waves worth 4, 5, 6… tanks, at least 2 minutes apart.
- No retreat, no recall, no scouting, no teamwork, no team role. Each wave goes at whatever it knows of you; it doesn't wait to outweigh your defence.
- Its faction changes only the unit mix, never the strength, so both factions meet a new player at the same pace.

**To beat it:** build a plant and a few tanks before minute 8, hold the first small wave, then counter-attack. Its army never passes 8 units.

### Normal: the default

**Personality:** a sound, all-round player. It expands, techs and defends itself, and attacks when it thinks it can win.

- Thinks every 1.3 s. 3 workers (Chaos 4), 2 items queued per factory.
- Opening: from its second generator its plant builds 2–3 tanks before more workers, and no third generator until they're out, unless power runs below 60%.
- Expands to any free deposit, nearest first. Second plant at 600 supply, advanced plant at 900, airfield and shipyard once established.
- Radar, anti-air on demand, one scout looping round your start, kiting artillery.
- Waves start at 8 tanks' worth, growing by 2 each time. Each wave waits to outweigh your known defence 1.5×.
- **Defends:** recalls its army against your waves, and **retreats** from fights it's losing.
- Techs with a T2 builder: upgraded extractors, a shield, Pinpointers, T2 defences, an anti-nuke. No nuke.

**To beat it:** it attacks what it has seen. Hide your defence from its scout, or make it look stronger than it is, and it keeps massing. Raid its far extractors; normal doesn't escort its workers.

### Hard (Hard - Balanced): the strong all-rounder

**Personality:** the full player. It's cautious about where it expands, patient about when it attacks, and it goes for the kill.

- Thinks every 0.7 s. 3 workers (Chaos 4), 2 items queued per factory.
- **Safe expansion:** it takes only deposits nearer its own start than any enemy start, and escorts workers to the far ones with 3 army units.
- Defences: from 5 extractors and 4 army units it builds gun turrets, 2 on the way home and one more per two far extractors. Order adds a turret and a Barrier wall across the front.
- Airfield and shipyard once 6 extractors and 6 army units stand. The airfield builds helicopters and bombers, and fighters against known aircraft. A fleet of 4 ships attacks on its own.
- **Big waves:** 12 tanks' worth, growing by 4. They outweigh your known defence 1.5×, and **hunt your Commander first**, since that ends the match.
- Retreats from lost fights. It doesn't recall against your waves (Order does); its turrets and the units at home hold instead.
- Full tech. Order adds a Citadel. When rich it builds a **nuke silo** and fires about once a minute at your best known target.

**To beat it:** its waves are rare but heavy and aimed at your Commander, so keep the Commander behind your defence. Contest the middle: it won't expand past the halfway line, so the map's far side is yours to take.

### Hard - Aggressive: pressure

**Personality:** hard's economy and tech, with no patience. It attacks early, attacks often and never backs down.

- Everything from hard except its caution:
  - waves start at 6 tanks' worth, growing by 2;
  - it attacks once its army is worth **0.8×** your known defence (outnumbered is fine);
  - **no retreat**, no turrets at home, no safe-expansion rule, no escorts to far deposits (Chaos still escorts its workers to contested ones).
- No recall, except Order, which still recalls its army against your waves.
- **Raids:** every 60 s, up to 4 fast units from home hit your nearest known extractor, between the waves.
- Builds a **bot lab**, so bots join the mix. Nukes when rich, like hard.

**To beat it:** turrets and a tight base win the early fights. It throws waves at them and never retreats, so its losses pile up. Guard your extractors against the raids, then strike while it rebuilds.

## 5. Faction styles

On top of the level. Easy keeps only the unit mix.

| | Order | Chaos |
|---|---|---|
| Army | more artillery (+10%); Wardens (deployable guns) are a quarter of its advanced plant's army | Locusts are a third of its T1 tanks; Minotaurs (siege) a quarter of its advanced plant's; the Tzar now and then, more against turrets |
| Waves | its pricier units make its waves later | two lanes (one round a flank); a Shroud jammer covers each wave |
| Economy | hard: only safe deposits, plus a gun turret at home | a worker more (it expands wider); workers wait for an escort before contested deposits |
| Defence | recalls its army against enemy waves on every level above easy; hard adds a Barrier wall and a Citadel | none extra |
| Bots | advanced bot lab: Fatboy | advanced bot lab: Centurion |

## 6. Team roles (2+ AIs on a side)

Two or more AIs above easy on one side share out roles in player order: **balanced, air, defense, spam, tech**, and around again. A lone AI plays balanced. Every AI above easy on a team also uses **teamwork** (section 3) and two-lane waves.

| Role | What it does |
|---|---|
| Balanced | its level as written above |
| Air | an airfield as soon as a plant and two extractors stand; 60% of its army production from the airfield; an advanced airfield when rich (Liche / Dragon, T2 aircraft); always builds anti-air |
| Defense | 4 more turrets, a Barrier wall, radar; waves 1.5× larger, so it holds ground while the others attack |
| Spam | a bot lab, 1 more item queued per factory; small frequent waves (×0.6 the size, growing by 1); little artillery: cheap units to overrun defences |
| Tech | the advanced plant at 400 supply instead of 900; a bot lab and its advanced lab; waves 1.3× larger |

## 7. Planned (the user, 2026-10-26; not built yet)

Ideas for the next AI pass. None of this is in the code; sections 1–6 describe what is.

### 7.1 The tech role builds the team's economy

In a team of 2+ AIs, the tech AI becomes the side's economy and T2 supplier instead of a slower fighter:

1. **Scale T1 power:** Solar Arrays, or Wind Turbines when the map's wind makes them beat a Generator.
2. **Rush T2:**
   - fund supply (orbs) and power with a Depot and by reclaiming its own factory;
   - build the advanced plant and **advanced constructors** (Architect / Forgemaster), and **give them to the frontline AIs**.
3. **Scale on T2:**
   - Fusion Reactors;
   - **share resources** with its allies.
4. **Past a resource threshold, spam T2 units** into the battlefield.

### 7.2 Roles pick their start spots

In the pre-game, roles choose start spots by position on the map:

- **Backline:** tech and air AIs.
  - With 8 AIs on a side: 2 tech and 1 air.
  - The other AIs choose their own roles.
- **Frontline:** AIs that can produce units and defences.
  - They hold off on T2 for a set time and wait for the tech AI's advanced constructors.
  - If those don't arrive in time, they go to T2 on their own.

### 7.3 Escorted large waves

A large wave goes with:

- a jammer;
- a radar vehicle;
- a mobile anti-nuke;
- anti-air, when the enemy uses aircraft.

Today a wave gets radar and fire-control vehicles on every faction. Only Chaos adds a jammer, and the mobile anti-nuke goes only once an enemy silo is known.

### 7.4 Defend the deposits early

In the early game, the AI secures its deposits (orb spots) with defence structures, so raids can't pick off its extractors.

Today only hard turrets its far extractors, and only after 5 extractors and 4 army units stand.

## 8. Known limits

- **It has no plan for the map.** It goes the shortest way to the nearest known target, and its lanes are fixed offsets, not chokepoints.
- **It doesn't learn.** It reacts to what it sees now (counters, recalls, retreats), but doesn't remember what worked earlier in the match.
- **Air and sea are simple.** Hard's and the air role's aircraft and the hard fleet attack on their own, not together with the ground waves.
- **Transports, Scavengers and Legion** aren't in its plans yet (roadmap).
- **The level reports are old.** `docs/AI_LEVELS.md` (2026-10-22) and `docs/FACTION_AI.md` (2026-10-23) predate S-187's rework (Hard - Aggressive, roles, teamwork, bots). They refresh with the next balance checkpoint (`lune run ailevels`, `lune run faction_ai`), which runs only on request.
