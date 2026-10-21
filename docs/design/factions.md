# Faction proposal: Order (heavy defense and strategy) vs Chaos (strength of armies)

Status: **approved by the user with one change (2026-10-22): IR SAMs Vigil 206, Thorn 165.** Stage 1 (the shared-role numbers, S-62) and stage 2 (Warden, Minotaur, S-63) are implemented; the numbers as built, with the ones tuned away from this document, are in `docs/BALANCE.md`, "Pass 3". The rest (faction AI, the other faction-only units) follows.

## 1. Intent

Both factions keep every shared role (guide 2.1: same roles, different stats), but each role is tuned along one personality.

- **Order** is the defender and planner. It wins when it chooses where the fight happens: from range, behind defenses, with information.
- **Chaos** is the army. It wins when it forces the fight: up close, in numbers, before Order's defenses and sensors pay off.

Every trait moves by **about 15–30%** between the two versions of a role. Order gets:

- longer range;
- better accuracy;
- more damage per shot;
- more health;
- slower fire;
- slower movement;
- a higher price;
- better sensors.

Chaos gets the opposite of each.

Per unit of value (supply + power / 10), the two versions of a role should come out about even: within 0.8–1.25 of each other in equal-value trades. What differs is the conditions each version wins in.

## 2. Updated guide 2.1 (proposed)

| | **Order** | **Chaos** |
|---|---|---|
| Ideology | Discipline, precision, control | Freedom, force, disruption |
| Role | Heavy defense and strategy | The strength of armies |
| Look | (unchanged) Western-inspired: sleek, wedge-shaped, fortress-like | (unchanged) Eastern-inspired: rugged, mass and assault |
| Unit traits | Longer range, more accurate, more damage per shot, tougher; slower firing, slower moving, more expensive | Shorter range, less accurate, less per shot but faster firing; lighter, faster, cheaper: more units for the same economy |
| Sensors | Better radar and sight, Pinpointers (S-59) reach full precision sooner, stealth | Weaker sensors; strong jamming and missile saturation instead |
| Exclusive tools | Deployable defenses, fortress structures, DIRCM | Siege units, mass-assault units, jammers |
| Strength | Wins information fights and fights it chose: at range, behind defenses, on a front it prepared | Wins brawls, attrition and tempo: attacks early, attacks wide, outnumbers |
| Weakness | Expensive and slow to reposition; loses if caught in the open or flanked; a broken line is costly to rebuild | Dies at range and against prepared defenses; fragile units bleed value; blind without jamming cover |

This **replaces** today's "Chaos: heavy armor". Several current stats contradict the new identity:

- The Ravager is tougher than the Lancer (1,300 against 1,100 health).
- The Juggernaut is tougher than the Paladin (3,000 against 2,600).

Section 3 turns them around.

## 3. Shared roles

Arrows give Order's direction against Chaos's version: ↑ Order higher, ↓ Order lower. The value is supply + power / 10. "Now" is today's def.

### 3.1 Main battle tanks, T1: Lancer / Ravager

| Trait | Dir. | Lancer now → proposed | Ravager now → proposed |
|---|---|---|---|
| Range | ↑ | 200 → 210 | 160 → 170 |
| Accuracy (spread °) | ↑ (less spread) | 0.5 → 0.4 | 2.0 → 1.6 |
| Damage per shot | ↑ | 140 → 165 | 150 → 125 |
| Reload (s) | slower | 1.6 → 1.8 | 1.4 → 1.3 |
| Health | ↑ | 1,100 → 1,300 | 1,300 → 1,000 |
| Speed | ↓ | 34 → 28 | 30 → 36 |
| Cost (supply / power) | ↑ | 150 / 1,500 → 170 / 1,700 (value 340) | 140 / 1,400 → 130 / 1,300 (value 260) |

- **Per value:** health per value is even (3.8 both). Damage per second per value: Lancer 0.27, Ravager 0.37.
- **Order wins:** at range. The Lancer outranges by 40 studs (+24%) and can kite with Maneuver.
- **Chaos wins:** closing fights and equal-value brawls, with 4 Ravagers for every 3 Lancers.

T2, Paladin / Juggernaut: the same directions. Paladin health 2,600 → 3,200, Juggernaut 3,000 → 2,500; ranges 231 / 210 → 240 / 195; reloads 2.4 / 2.4 → 2.7 / 2.0; costs value 640 → 720 / 640 → 560.

### 3.2 IR SAMs: Vigil / Thorn (sites), Halo / Hornet (mobile)

**After the user's cuts (S-55, S-56), the Vigil reaches 147 studs and the Thorn 206: Chaos outranges Order, against Order's identity.** Proposed:

| Trait | Dir. | Vigil / Halo now → proposed | Thorn / Hornet now → proposed |
|---|---|---|---|
| Range = lockRange | ↑ | 147 → **250** | 206 → **200** |
| airSight (sites, mobiles) | ↑ | 157 → 250 | 206 / 147 → 200 |
| Damage per missile | ↑ | 220 → 240 | 200 → 180 |
| Reload (s) | slower | 2.5 → 2.8 | 2.0 → 1.7 |
| Stock (S-47) | ↑ per site, ↓ per missile cost | 8 / 4 → 8 / 4 (missile 15 + 300) | 8 / 4 → 10 / 5 (missile 12 + 240) |
| Site health | ↑ | 1,100 → 1,300 | 1,000 → 900 |
| Cost (value) | ↑ | Vigil 220 → 240 | Thorn 200 → 180 |

- The 250 / 200 pair keeps the user's overall cut: the average of 147 and 206 is 177, the new pair averages 225, close to S-55's 252. If the user wants the cuts kept exactly, use **Vigil 206, Thorn 165** (Order +25%).
- **Order wins:** air cover over a held position, with fewer, surer kills.
- **Chaos wins:** saturation. Many cheap missiles against flares and DIRCM, more launchers per supply.

### 3.3 Radar SAMs: Aegis / Wyvern (sites), Seraph / Gorgon (mobile)

| Trait | Dir. | Order now → proposed | Chaos now → proposed |
|---|---|---|---|
| Range | ↑ | 1,013 → 1,100 | 945 → 880 |
| Own radar | ↑ | Aegis 1,097, Seraph 878 → 1,200 / 950 | Wyvern 1,013, Gorgon 810 → 950 / 760 |
| radarError (wobble) | ↓ | 20 → 15 | 45 → 50 |
| Damage | ↑ | 380 → 420 | 400 → 340 |
| Reload (s) | slower | 4.0 → 4.5 | 4.0 → 3.4 |
| Stock / refill (S-52) | | 15 sites, 3 mobile; 6 s | 15 → 18 sites, 3 → 4 mobile; 6 → 5 s |
| Interception chance (S-50) | ↑ | 0.2 → 0.25 | 0.2 → 0.15 |

- **Order wins:** long, precise coverage. With Pinpointers its radar missiles hold their lock at range, and its nuke defense is reliable.
- **Chaos wins:** volume. More missiles in the air, against a jammed sky (its own jammers degrade the enemy's radar).

### 3.4 Artillery: Verdict / Hellmouth (T1), Judgement / Hydra (T2 MLRS), Edict / Cataclysm (emplacements)

| Trait | Dir. | Order (Verdict, Judgement, Edict) | Chaos (Hellmouth, Hydra, Cataclysm) |
|---|---|---|---|
| Range | ↑ | 450 / 528 / 450 → 480 / 560 / 520 | 400 / 480 / 400 → 380 / 440 / 400 |
| Accuracy (°) | ↑ | 0.6 / 1.5 / 0.6 → 0.5 / 1.2 / 0.5 | 1.6 / 3.0 / 1.6 → 2.0 / 3.5 / 2.0 |
| Damage per shell | ↑ | 420 / 234 / 420 → 460 / 260 / 480 | 440 / 286 / 440 → 360 / 240 / 400 |
| Reload (s) | slower | 4.0 / 6.0 / 4.0 → 4.4 / 6.5 / 4.4 | 3.5 / 6.0 / 3.5 → 3.0 / 5.0 / 3.0 |
| Health | ↑ | 700 / 900 / 4,000 → 800 / 1,000 / 4,800 | 820 / 1,000 / 4,400 → 700 / 850 / 3,800 |
| Speed | ↓ | 26 / 28 → 24 / 26 | 24 / 28 → 28 / 32 |

- **Order wins:** counter-battery and sieges of fixed lines. Precise long shells guided by radar tracks (fire-control radar, Pinpointers).
- **Chaos wins:** barrages in support of a push. Faster salvos, shorter range, it moves up with the army.

### 3.5 Fighters: Falcon / Harpy (T1), Archon / Manticore (T2)

| Trait | Dir. | Order now → proposed | Chaos now → proposed |
|---|---|---|---|
| Missile range | ↑ | 320 / 420 → 340 / 440 | 280 / 340 → 260 / 320 |
| Missile accuracy / guidance | ↑ | IR 0.5°, radar → same; DIRCM | IR 1.2° → 1.4°; flares |
| Damage per missile | ↑ | 260 / 300 → 280 / 330 | 200 / 340 → 190 / 280 |
| Reload (s) | slower | 1.2 / 2.0 → 1.4 / 2.2 | 0.9 / 1.0 → 0.8 / 0.9 |
| Health | ↑ | 520 / 800 → 600 / 900 | 560 / 950 → 480 / 800 |
| Speed | ↓ | 260 / 300 → 240 / 280 | 240 / 280 → 270 / 310 |
| Cost (value) | ↑ | 480 / 1,060 → 520 / 1,100 | 420 / 950 → 380 / 880 |

- **Order wins:** standoff interception, picking aircraft out of range, and radar-guided Archon shots under Pinpointer precision.
- **Chaos wins:** dogfights and numbers. Faster, cheaper, more missiles in a merge.

### 3.6 Scouts: Herald / Jackal

| Trait | Dir. | Herald now → proposed | Jackal now → proposed |
|---|---|---|---|
| Sight | ↑ | 280 → 300 | 260 → 220 |
| Speed | ↓ | 70 → 60 | 66 → 76 |
| Weapon | | mg 165 r, 36 dmg → 175 r, 40 dmg, reload 0.45 | mg 150 r, 40 dmg → 140 r, 34 dmg, reload 0.35 |
| Health | ↑ | 300 → 340 | 320 → 280 |

- **Order wins:** seeing. Its scouts spot farther, and the sight feeds artillery and radar SAMs.
- **Chaos wins:** raiding. Fast harassment of extractors and workers.

### 3.7 Workers: Mason / Scrapper, Architect / Forgemaster

| Trait | Dir. | Order | Chaos |
|---|---|---|---|
| Build power | ↓ per unit | 100 → 110 | 100 → 90 |
| Health | ↑ | 650 → 750 | 700 → 600 |
| Speed | ↓ | 30 → 28 | 28 → 32 |
| Cost (value) | ↑ | 270 → 300 | 240 → 220 |

- **Order wins:** builds defenses in place with fewer, sturdier workers.
- **Chaos wins:** expands faster and rebuilds more cheaply after losses.

### 3.8 Radar: Watchtower / Eye, Beacon / All-Seer, Oracle / Watcher, Pinpointers

| Trait | Dir. | Order now → proposed | Chaos now → proposed |
|---|---|---|---|
| Radar range | ↑ | Watchtower 650, Beacon 1,100, Oracle 700 → 700 / 1,250 / 760 | Eye 600, All-Seer 1,000, Watcher 600 → 560 / 950 / 560 |
| radarError | ↓ | 15–20 → 12–16 | 40–45 → 45–50 |
| Pinpointer (S-59) | ↑ | Witness: full at 5 | Augur: full at 7 |
| Health / cost | ↑ | +15% / +15% | −15% / −15% |

- **Order wins:** information. It sees first and sees precisely, so its precision weapons hit.
- **Chaos wins:** denial. Its jamming (Smog, Blackout, Shroud) cancels Order's sensor lead, and its cheap radar is spammable.

## 4. Faction-only units

**Order: deployable defenses and fortress structures**

| Unit | Tier | What it is | Wins / counters |
|---|---|---|---|
| **Warden** (deployable gun) | T2 vehicle | A tracked heavy gun that unpacks in 4 s into a fortified emplacement: range 280, health ×1.5 deployed, cannot move while deployed. | Turns a taken position into a line; counters Chaos pushes; weak to artillery and to being caught packed. |
| **Phalanx** (shield projector) | T2 vehicle | Deploys a dome (radius 60) that absorbs 3,000 damage from projectiles entering it, recharges 100/s while not hit. | Protects artillery and SAMs from saturation; countered by sustained fire and siege units. |
| **Citadel** (fortress) | T3 structure | A large turret block (range 320, 9,000 health), with radar and an IR SAM. Costly (value ~2,000). | Anchors a front or a choke; the Normandy draws and bridges. Countered by Chaos siege units and nukes. |
| **Barrier** (wall segments) | T1 structure | Cheap blocking walls (1 cell, 2,500 health) that block movement and low direct fire, like Normandy's hedgerows. | Funnels Chaos armies into kill zones; artillery and siege break them. |

**Chaos: siege and mass assault**

| Unit | Tier | What it is | Wins / counters |
|---|---|---|---|
| **Locust** (swarm tank) | T1 | A very cheap light tank (value ~150, 600 health, speed 45, a short-range autocannon), built in pairs. | Saturation and flanking; overwhelms single-target precision; dies to splash (MLRS, flak). |
| **Minotaur** (siege ram) | T2 | A super-heavy assault vehicle with +50% damage against STRUCTURE, a demolition charge (one-shot 3,000 at 30 studs), slow. | Breaks walls, turrets, Citadels; countered by mobile units and air. |
| **Cyclops** (siege mortar) | T2 | A heavy mortar, range 520 but only against STRUCTURE (it can't track units), 1,200 damage, reload 8 s. | Out-ranges static defenses so they must be answered by mobile units; useless against an army in the field. |
| **Wraith swarm** (decoy drones) | T2 air | Cheap drones that look like aircraft on radar; draw interceptors and radar SAM shots. | Drains Order's SAM stockpiles (S-47) ahead of a real air raid or a nuke. |

## 5. Intended match flow

- **Opening (0–6 min):** Chaos expands wider and fields more units sooner, and should look for an early win or heavy raid damage. Order expands to fewer, safer deposits and covers them with Bulwarks, Vigils and a Watchtower. It aims to survive the opening with less map but no big losses.
- **Midgame (6–15 min):** Chaos holds the initiative and attacks in waves, trading cheap units for Order's map. Order builds its line (Wardens, Barriers, artillery behind radar and Pinpointers) and wins trades whenever Chaos attacks into it. The front settles where Chaos's numbers meet Order's prepared ground.
- **Late game (15+ min):** Chaos needs siege (Minotaur, Cyclops) and decoys to crack fortified fronts, or saturation air and nukes. Order converts its information lead into precision strikes (radar-tracked artillery, standoff fighters, the nuke from behind its interceptor umbrella) and pushes out slowly.
- **Comeback rule:** a Chaos army that stops attacking loses its edge as Order fortifies. An Order line that is broken costs far more to rebuild than Chaos's losses. Both sides therefore have a reason to act.

## 6. How balance will be measured

- **Faction win rates:** `lune run ailevels` and `lune run balance` gain a faction axis.
  - Matches: Order AI against Chaos AI at every level pair (easy/normal/hard both ways), on every map (Ridgeline, Coastline, skirmish:256, Twin Lakes, Crossroads, Normandy).
  - Starts: both, with 3+ seeds each.
  - Target: each faction wins **40–60%** of the mirrored-level matches overall, and **35–65%** on every single map.
- **Shared roles:** the equal-value trades in `docs/BALANCE.md` stay within **0.8–1.25 overall** for every role pair (close and long starts averaged).
  - Each version must also win **its own condition**: Order above 1.25 at long range or against a prepared defense, Chaos above 1.25 at close range or with a numbers advantage.
  - New scenarios for that: *defended line* (Order gets 30 s to deploy) and *flank* (Chaos arrives from two sides).
- **Counter matrix (guide 12.4):** the counter check keeps passing. Faction-only units get rows of their own: siege beats structures, swarm beats precision, Warden beats a frontal push.
- **Pace:** median match length per map stays within ±30% of today's, and no map has more than 10% of matches undecided at the 40-minute limit (a stalemate guard; see risks).

## 7. AI changes per faction

- **Order AI:**
  - Expands to fewer, safer deposits (the Hard `safeExpansion` rule for every level).
  - Builds defenses first at each expansion (Bulwark and Vigil, Warden later), plus Pinpointers and Beacons once at T2.
  - Attacks later and with artillery and radar escort (the S-7 rule, more weight).
  - Holds a defensive line (`recall` at every level above Easy, S-57).
  - Builds the nuke and the interceptor umbrella before the late game.
- **Chaos AI:**
  - Expands wide and early, with more workers.
  - Sends smaller, earlier and more frequent waves (wave growth +1, a shorter first wave), with flanking waves on two lanes.
  - Builds jammers (Smog, Blackout) with each wave, and siege units once it meets structures.
  - Uses decoy drones ahead of air raids and nukes.
- **Levels stay level-shaped (S-57):** Easy is gentle whichever faction it plays, and Hard > Normal > Easy holds for each faction separately; the level report gets a per-faction tally.

## 8. Risks

- **Stalemates:**
  - The risk: an Order AI or player that only turtles, against a Chaos side that can't break a fortified line, gives 40-minute draws.
  - Mitigations:
    - siege units that outrange static defenses;
    - Order's economy can't hold a whole map line (fortress structures are expensive);
    - nukes as a late-game breaker;
    - the undecided-at-limit guard in section 6.
- **New players:**
  - The risk: Order's slow units and prepared play are less forgiving to someone who doesn't plan, while Chaos's fast cheap units reward aggression even when it's sloppy. Easy AI against a new player must not feel unbeatable as Chaos or unbreakable as Order.
  - Mitigations: tutorials and the default faction (Chaos?), Easy AI tuning per faction, clear range rings (client).
- **Reversal of current stats:** Chaos is "heavy armor" today (Ravager, Juggernaut, Hellmouth tougher). The proposal flips that, so every existing balance pass (S-22, S-30) has to be redone, and the client's look (Chaos heavy, Order sleek) no longer matches "Order tougher". The look may need a pass: Order fortress-like *and* sleek still works, but the art direction should say Order's armor is the heavier.
- **Information asymmetry:** Order's sensor lead plus Pinpointers plus precision can snowball; Chaos jamming must stay a real answer (burn-through, Pinpointer counts under jamming).
- **Scope:** four faction-only units each, plus the trait passes, is a full balance milestone (M8). Recommend staging:
  1. Shared-role trait pass (defs only, measured).
  2. One faction-only unit per side (Warden, Minotaur).
  3. AI faction behaviour.
  4. The rest of the faction-only units.
