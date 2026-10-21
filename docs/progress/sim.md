# Simulation progress

Progress of the headless simulation stream: `src/shared` (except `Defs/Blockouts/`), `src/server`, `.lune/` and the balance and stress tooling, run under Lune. It continues on branch `m-sim-2`. The Roblox client and Studio work (`src/client`, `src/shared/Defs/Blockouts/`, place content) is another stream with its own file in this folder; this stream doesn't edit those areas.

Decisions: D1–D109 (before the split) in `docs/DECISIONS.md`; this stream's new decisions are `S-1`, `S-2`, ... in `docs/decisions/sim.md`. A new session should be able to continue from this file alone.

## Summary (latest: overnight 2026-10-22, branch `m-sim-2`; everything merged into `main`)

**Overnight** (the user's five tasks, with the client's requests 34–36 first, as they came). Protocol 18 → 20. Tests: 345 in 51 specs → 356 in 52 (350 fast, ~36 s; 6 slow, ~40 s). Every commit passed the fast suite; every merge into `main` passed fast, slow and the build.

| Task | Result | Decision |
|---|---|---|
| 1. AI levels | Easy: no attack before 8 min, waves of 4 +1 two minutes apart, an army of 8. Normal: 2–3 tanks before its third generator, recalls its army against an enemy wave near the base. SAM stockpiles measured against helicopter raids (empty-with-a-target 44% → 31%) and fixed in the AI: refill power counted, half the mobile SAMs stay home, production pauses for refills under a stall. The integration's slow suite caught a side bias in Normal mirrors (rally points inside each other's artillery range); fixed. **Hard > Normal > Easy on every map** (Normal–Easy 36–6, Hard–Normal 42–0, Hard–Easy 36–0; was Easy–Normal 23–19) | S-57 |
| 2. Faction proposal | `docs/design/factions.md` (write-only): an updated guide 2.1, numbers per shared role (Order longer range, accuracy, damage per shot, toughness, sensors, price; Chaos the opposite), faction-only units, match flow, measurement plan, AI per faction, risks. Proposes **Vigil 250 / Thorn 200** (Order outranges again) | — |
| 3. Normandy performance | New `lune run profile_normandy`. Route search, flow fields and slot assignment do the same work faster; the state hash is unchanged. Worst tick 16–25 → 11–15 ms, p99 12–14 → 8–9 ms; Pathing peak 12–19 → 7–8 ms, Projectiles+Damage 7–11 → 6.5–10, NetOut 5–7 → 4. **Still over:** Commands on a select-all order (1.7 ms, budget 1) and a structure death's quadtree updates (~6 ms); proposals under "Needs my review" | S-60 |
| 4. Baseline | `docs/BALANCE.md` "Baseline": counter check 439 → 444 pairs holding; mobile radar SAMs weaker, bombers stronger, Hornet stronger. AI levels unchanged by the SAM changes alone. Stress (800 units) Pathing 11.1 → 5.1 ms; the soak's default seed is now 4 (25.5 min, replay identical) | — |
| 5. Integration | Client C-59 … C-73 and models M-12, M-13 merged, all passing; no conflicts | — |
| Client requests | 29: interception chance 0.2. 28: nukes climb vertically, then turn (shared `Lofted`, protocol 18). 30: radar SAM stock 15. 31: `map:normandy`, re-oriented west–east by the user (S-54). 32, 33: SAM ranges −30% IR / −25% radar, twice. 34: Pinpointers (radar precision). 35: a unique icon per unit type (protocol 19). 36: own units' queue, fire / move state, ammo on the wire (protocol 20) | S-50 … S-61 |

**Earlier on 2026-10-22** (requests 25–27): SAM missile stockpiles (protocol 15), nuke silos with radar SAM interception (protocol 16), lower nuke arc and stockpile progress (protocol 17). S-47 … S-49.

**Needs my review** (below) gained: the AI level numbers and the refill-priority question (S-57); Pinpointer numbers (S-59); radar SAM stock and the range cuts (S-52, S-55, S-56); the two remaining performance peaks (S-60); the faction proposal itself.

## Summary (previous round: second round of 2026-10-22)

**This round** (the user's seven tasks, the client's requests first, then the soak and the AI level report). Protocol 9 → 13. Tests: 299 in 41 specs → 331 in 48 (325 fast, ~34 s; 6 slow, ~35 s).

| Task | Result | Decision |
|---|---|---|
| 1. Client requests 9, 10, 13 (+13d, 14–19 that came in during the round) | Team sight map and wrecks on the wire (protocol 10; ~0.5 KB/s per player at 800 units, a join ~2 KB). IR SAMs: the miss was a one-tick aim misalignment, not the fuse; proportional navigation (`Shared/Combat/Guidance`, shared with the client) and a seeker cone: a circling Falcon now takes 90% of the Thorns' missiles (was 33%), the rest are DIRCM decoys. Decoyed missiles bend toward the decoy (protocol 11). Then: MOVING bit, projectiles burst at the map edge, Thorn range 420 / blast 12 (asked; review), jets fly to their move goal, DECOYED names the countermeasure (protocol 13), no wrecks for aircraft shot down | S-26, S-27, S-28, S-33, S-38 |
| 2. Overkill-aware targeting, T1 re-check | A weapon doesn't fire at a visible target that shells already on their way will kill (weighted by an estimated hit chance, checked against fired shells); decided at the trigger so a volley spreads: 6 Verdicts vs 6 one-shot tanks, 12 shells / 6.3 s instead of 30 / 18.9 s. Targeting cost unchanged. It didn't move artillery: without spotters both fire at sight range. One retune: Verdict sight 140 → 170 (long artillery fight 0.58 → 0.97) | S-29, S-30 |
| 3. Twin Lakes 2v2 bias | Traced like S-23 (mirrored players' decisions): the generator rule read the power stall ratio at think time, which reads 1.0 just after a builder finishes, and think offsets decided which side caught that moment. Then two more causes on Ridgeline: think phases against the 5-tick economy / 2-tick sensor steps, and the server's site snap rounding half cells toward +x. Fixed all three; Hard–Normal on Twin Lakes 3–3 by side (was 0–6) | S-31 |
| 4. Coastline stalemates | Not the map: attack-moves held on enemies across the inner ridges, shooting into the cliff, because direct fire went through hills. Line of fire built (task 5's first item): 0 of 36 Coastline matches at the limit (was 31). The level report no longer counts "on value" as a win | S-32 |
| 5. Audit gaps | Line of fire; move states (Hold Position / Maneuver / Roam); CANCEL with a refund (protocol 12); carriers recover, carry and launch aircraft; terrain types and speed modifiers (MapGen paints sand and rock); amphibious units submerge, hover units ride the surface | S-32, S-34..S-37, S-39 |
| 6. Test suites | `lune run test` (fast, every commit) and `lune run test_slow` (AI matches, fairness; run by `integrate.sh`); `CLAUDE.md` documents both | S-40 |
| 7. Replay compression | Noted under "Launch items"; not built | — |

**Soak** (`lune run soak`, now seed 11): with this round's AI and combat no seed of 1–13 lasts 40 minutes (8–33 min); seed 11 is the longest. 32.6 min, 29,305 ticks in 18 s, at most 85 units; tick avg 0.60 ms, p99 2.19, peak 11.3 ms (Pathing 9.8); heap flat at 10–18 MB (217 KB per unit at minute 5, 189 at minute 32); replay identical. The spectator replay (5.8 MB, 178 KB per game minute) is now recorded in a second run of the same match: kept in memory, it grows with time, and with today's smaller armies it made the per-unit heap look like a leak (it failed the check at 920 KB per unit; without it the heap is flat). S-41.

**AI levels** (`docs/AI_LEVELS.md`, 126 matches, 3 seeds, Command Ends; "on value" no longer counts): **every match now ends by a win condition** (none at the 40-minute limit; Coastline median 6.4 min, was 31 of 36 at the limit). Hard beats Easy 36–0 and Normal 37–5. **But Easy beats Normal 23–19:** Easy wins on the 128-cell maps (Coastline 11–1, Ridgeline 8–4), Normal on `skirmish:256` (10–2) and Twin Lakes (4–2). Matches on the small maps end at ~4.5 min: Easy's first wave of 8 reaches Normal's Command Vehicle while Normal has 2–3 army units, its economy (17 structures to Easy's 13) not yet turned into an army. Likely why it shows now: before line of fire (S-32), attack-moves stalled behind the ridges, so early waves rarely got through. The S-31 stall memory is part of it (without it 6–6 on Ridgeline) but not all; trials were noisy. **Not fixed:** it needs a Normal early-defence / build-order change, proposed for the next round.

**Integration:** 16 client commits and 2 from the new models stream merged this round, all passing; no conflicts. `main` is at the last merge below.

## Summary (previous round, 2026-10-22: tasks 1–7, S-19..S-25)

**This round** (the user's seven tasks, then the soak and the AI level report):

| Task | Result | Decision |
|---|---|---|
| 1. Integration worktree | Merges and their checks run in `../FTGG-integration` (a worktree on `main`) with `tools/integration/check.sh` / `integrate.sh`; `CLAUDE.md` "Integration". The client's resolved merge `dfdd0e7` brought in its 8 blocked commits; 15 client commits integrated this round, all passing | — |
| 2. Build ranges (client request 7) | 56 / 45 / 34 (70%). Found and fixed: frames started in range of the clicked point but built only in range of the snapped center | S-19 |
| 3. Aim rest pose and restore delay (client request 8) | `restYaw` / `restPitch` / `restoreDelay` on turrets; `Shared/Combat/Aim` is the exact step for server and client. Juggernaut arms rest at -65°, rise at 80°/s (12 ticks before the first shot), hold 3 s | S-20 |
| 4. Spectator economy | Eco records carry their team (protocol 9); spectators and replays get every team's | S-21 |
| 5. T1 ground balance | Six numbers (all Chaos but Order's light-cannon range). Lancer vs Ravager 0.38 → 1.00 / 0.82 (1.26 / 1.00 with three seeds after S-23); scouts 0.61 → 0.82 / 0.80 (0.91 / 0.71 after S-23); artillery 0.55 / 0.73 → 0.61 / 0.80 (0.51 / 0.58 after S-23). See "Needs my review" | S-22 |
| 6. Start-position bias | Cause: the targeting stagger `(id + tick) % 6` followed ID parity while Sensors runs on even ticks, so even IDs (player 2's in mirrored matches) reacted sooner: mirror tank fights 40-0 for the even side. Fixed with a hashed phase (4-10, 26 draws); mirror AI matches 6-6; `Fairness.spec`. Also: AI artillery now follows its tanks (S-24), Easy has a production handicap (S-25) | S-23, S-24, S-25 |
| 7. Guide audit, sections 6-13 | 20 gaps by importance, below (move states, line of fire, terrain types, amphibious / hover, carriers, cancel, ...). Not implemented | — |

**Soak** (`lune run soak`, now seed 2: seed 3 ends at 8.4 min with the new AI): 40 min, 36,000 ticks in 36 s, at most 244 units; tick avg 0.99 ms, p99 3.26, peak 23.3 ms; heap 7.7 → 73 MB, flat per unit (~310 KB at minutes 5 and 40); replay identical; the spectator replay of the 40 minutes is 16.8 MB raw.

**AI levels** (`docs/AI_LEVELS.md`, 126 matches, 3 seeds, 40 min, Command Ends): Normal beats Easy 29-13, Hard beats Easy 25-11, Hard beats Normal 24-18. Ridgeline is clean (Hard-Normal 10-2, Normal-Easy 11-1, Hard-Easy 12-0). Open:
- **Coastline stalls:** 31 of 36 matches reach 40 minutes, and called on value a passive Easy "beats" Hard 9-3. Why the armies don't finish there (the northern sea, passes, or the waves) isn't diagnosed yet.
- **Twin Lakes 2v2:** Hard-Normal goes to the east pair in all 6 matches, though a Normal-only 2v2 mirror splits 3-3. Not diagnosed.
- `skirmish:256` is not exactly mirrored (S-23); its Hard-Normal 5-7 says little.

**Tests:** `lune run test` gives **41 specs, 299 passed, 0 failed** (~65 s; `Fairness.spec`'s mirror matches take ~33 s). New this round: `Aim.spec` (4), `Fairness.spec` (3), `PlayerReplay.spec` economy checks, and Build, Defs, Schema cases. `lune run build`: 337 scripts, 1050 requires.

## Summary (overnight 2026-10-21)

**Done:** the whole queue (tasks 1–6), all four client requests (1, 2, 4, 5), and integration of every client commit marked ready. Each piece was merged into `main` with `--no-ff` after `lune run test` and `lune run build` passed, then pushed. The hourly integrator loop is running (cron job `af888f92`, session-only).

| Task | What | Decision |
|---|---|---|
| 1 | `docs/contracts/net.md`: everything the client receives (marked ready); `Ballistics` and its homing steer moved to `Shared/Combat` | S-1 |
| 2 | Join / reconnect: HELLO / REJECT / WELCOME handshake, full rebuild after a join, Eco channel (protocol 6). A late-joining client rebuilds exactly the same view | S-2 |
| 3 | Order queues: shift-queue, FIGHT (holds to engage), PATROL, ATTACK (forced fire, team knowledge), GUARD, REPAIR (also heals), RECLAIM / BUILD queues, factory rally and repeat | S-4 |
| 4 | Movement peak at 800 units 12.1 → 6.4 ms (budget 10): field extensions are now sliced Pathing jobs | S-5 |
| 5 | Smarter AI: radar tower, fire-control radar via the Advanced Vehicle Plant escorting waves, kiting artillery, IR SAM trucks and sites against known aircraft | S-7 |
| 6 | `lune run soak`: 40-minute AI-vs-AI match, 36,000 ticks in 16 s; peak tick 10.8 ms, heap 6–16 MB with no growth, replay identical | S-8 |
| Client requests | Weapon pieces in `pieces` plus validation (S-3); unit state bits in Shared, `Schema.UnitState` (S-6); placement rules in Shared, `Shared/Grid/PlacementRules` (S-9); icon numbering in Shared, `Shared/Net/Icons` (S-10) | S-3, S-6, S-9, S-10 |

**Tests:** `lune run test` gives **36 specs, 272 passed, 0 failed** (253 at the start). New: `Orders.spec` (8), `AI.spec` (4), plus tests in `NetOut.spec` (4), `Schema.spec` (2), `Defs.spec` (1) and `Placement.spec` (1). Every new mechanism was mutation-checked (its test fails when it is undone). `lune run build`: 288 scripts, 861 requires.

**Integrated from the client stream:** `a2371cd`, `f815a5d`, `7bbaa7b`, `89e7db1`, `a96cca2`, `2062b10`, `df29a2d`, `f52bf53`, `47aaa63`, `afe8aea`, `b8405ff`, `508b215`, `002cc39`. No conflicts and no failed checks (see Integration notes).

**Balance** (re-run after FIGHT started holding to engage): 448 of 568 pairs hold (was 457); 206 findings (75 mechanic, 131 numbers); same-role band 24 of 38 (was 34). See "Needs my review".

## Guide coverage audit, sections 6–13 (2026-10-22)

What the guide asks of the simulation and isn't implemented (or only partly), most important for gameplay first. Not implemented yet, by request. Size: S small, M medium, L large.

**Status after the 2026-10-22 round:** 1 done (S-34), 2 done (S-32), 3 done (S-37), 4 done except a hover roster unit (S-39), 5 done except carriers building aircraft (S-36), 6 done (S-35), 8 overkill done (S-29; focus fire not). The rest stand.

1. **Move states do nothing** (10.1, M). Maneuver (chase a little, come back), Roam (chase freely) and Hold Position are stored (`World.moveState`, SET_MOVE_STATE) but nothing reads them: idle units never chase, so everything behaves as Hold Position. Fire states work.
2. **No line-of-fire check** (10.8, M). Hitscan, beams and direct shells should check the height layer and hold or reposition when terrain blocks; direct fire goes through hills (10.7 lists it as "not yet").
3. **No terrain types or speed modifiers** (5.2 `terrainType`, 6.3, 12.1 "heavies slow on sand"; M). No `terrainType` layer, flow-field step cost always 1 (D30), Movement ignores terrain.
4. **Amphibious and hover only half done** (6.1, 12.3; M). Pathing works (HOVER on any water, AMPHIB on the sea floor), but AMPHIB never becomes SUBMERGED underwater (stays a visible GROUND unit, torpedoes can't target it), no roster unit is HOVER, and `Combat.baseAt` would put a hover unit on the sea floor for aiming and hits.
5. **Carriers partial** (12.2, 12.3; M). Sanctuary and Leviathan have rearm pads that `Air.nearestPad` uses, but aircraft can't be assigned a carrier as home base, a rearming aircraft doesn't move with its carrier (D88), and carriers don't hold, build or launch aircraft.
6. **No cancel for construction** (9.3, S–M). No command to cancel an unfinished frame or a factory queue item (D62); "cancelling refunds what was spent" has nothing to act on.
7. **Salvos and target leading** (10.7, 11.6, 13.2 Hydra; S–M). `salvo { count, delay }` is in the schema but never read (all defs use count 1); ballistic shells don't lead moving targets (only bombs and homing missiles do).
8. **Targeting heuristics** (10.2, S). No focus-fire bonus, no overkill penalty (D44), one stagger for all weapons. The overkill penalty is also the likely fix for close-range artillery balance (S-22, "Needs my review").
9. **Logistics costs incomplete** (8.6, S). Missile reloads for SAM sites and launchers are free; plain radars (towers, Oracle, AWACS) have no power upkeep; no power-drawing energy weapons.
10. **Landing details** (12.2, S). Landed aircraft keep the AIR category (ground guns can't hit them, the guide says "easy targets"); `Air.nearestPad` ignores how busy a pad is; no flying sight bonus, so landing loses nothing.
11. **Fusion Reactor has no death explosion** (8.5, S).
12. **Group speed matching** (6.6, optional, S). No flag, Nav doesn't do it.
13. **Non-square footprints** (9.3, S). `footprint` is one number, so facing changes nothing.
14. **Friendly fire per match** (10.6, S). `Combat.friendlyFire` is fixed on; not a match option.
15. **Roster holes** (9.1, 12.3; S): no naval SAM platform, no advanced rearm pad.
16. **BEAM damage over time** (10.4, S): BEAM resolves like hitscan; no BEAM weapon exists yet.
17. **Networking details** (7.2, 7.3; S): fast jets get no wider tactical margin; the ALERT event and the strategic "under attack" flag aren't sent.
18. **ATTACK_GROUND only for bombers** (D100, S): artillery can't force-fire at a spot.
19. **Optional:** terrain-occluded line of sight (11.2), elevation sight bonus (5.5).
20. **Roblox-only, later:** Parallel Luau Actors for field generation (6.4, D28, D29).

Not in sections 6–13 and also not implemented: transports (load / unload), cloaking, capture, self-destruct, stockpiled weapons (nukes, anti-nukes), shields, resurrect, veterancy, morph. The "stunned" and "cloaked" state bits named in 7.3 have no feature behind them.

Deliberate differences from the guide (decided, recorded): submarines are never VISIBLE, only sonar contacts (D76–D78, guide 11.3 says "or VISIBLE within close sonar range"); sensor counts are u16 and visibility is recomputed every sensor tick (D65); economy income is recomputed each 3 Hz step instead of kept as a running total (8.3); at the projectile cap a new shot resolves like hitscan (the guide: the oldest ballistic shells resolve at their predicted impact); wrecks are a list in `Combat`, not grid features, and don't block movement (8.7).

## Needs my review

- **Faction pass (S-62; BALANCE.md "Pass 3"):** 12 of 12 shared roles in 0.8–1.25. Your calls:
  - **Tuning away from the proposal:** every step is listed in Pass 3; all are within ±10% of its numbers except three:
    - the T1 tank turret yaw rates (Order 100, Chaos 130 °/s);
    - the T2 cannon damages (Paladin ×1.15, Juggernaut ×0.75), where the proposal gave no number;
    - the Archon's DIRCM 0.68.
  - **Conditions not met:**
    - T1 fighters are even at every start: jets close 600 studs in ~2 s, so Order's standoff never shows.
    - The Herald doesn't win at range (0.82): its 35-stud edge is half a second of a Jackal's run.
    - The Hydra wins neither close nor flanking: re-measured after the salvos (task 7).
  - **Proposal silent, I followed the direction:**
    - Halo 660 / Hornet 480 health (were 500 / 560);
    - Herald / Jackal costs 121 / 99;
    - machine gun accuracy 1.35 / 1.65.
  - **Look:** Order's units are now the tougher ones; guide 2.1's look row still reads "Chaos: built for mass and assault", which fits, but the art direction may want Order's armor to read heavier (factions.md, risks).
- **Performance (S-60):** two peaks are still over their guide 18.1 budgets, because the fixes change timing. Commands takes 1.7 ms on a ~300-unit select-all order (budget 1); proposal: slice the order's slot assignment into the Pathing job. A structure's death costs ~6 ms in Damage (quadtree updates); proposal: lazy quadtree updates.
- **AI levels (S-57):** Easy's numbers (first wave at 8 min, waves of 4 + 1, 2 min apart, army of 8, a unit per 20 s); Normal's 2 tanks before the third generator and its recall rule. **Design question:** missile refills share a stalled economy evenly with construction, so an AI (or player) under air attack keeps its SAMs empty. Should refills take priority over construction?
- **Pinpointers (S-59, the user asked):** names Witness and Augur; full precision at 6 (linear); 90% less radar and track error at full; radar-only missile lock loss 10% per midcourse check without Pinpointers (a long shot fails about a third to half the time); cost 250 + 3,000.
- **SAM ranges cut again (S-56, the user asked):** IR now 49% of its S-33 range, radar 56% of S-45's. **Nukes:** a nuke is now in a radar site's reach for only ~6 s, so two sites often let one through (the test now uses four). If interception should stay strong, raise the chance or the radar SAM stock again.
- **Shorter SAM ranges (S-55, the user asked):** IR −30%, radar −25%. My call: the units' air sight and radars shrink by the same factor. A side effect is a shorter interception window for nukes.
- **Radar SAM stock (S-52, the user asked):** Wyvern / Aegis capacity 15, 6 s per missile. My calls: the cost per missile stays 40 + 900 (a full refill 600 + 13,500), mobile radar SAMs stay at 3, IR SAMs unchanged.
- **Nuke silos (S-48, the user asked through the client):** names Reckoning (Order; "Judgement" was taken by the MLRS) and Ragnarok (Chaos); silo 2,400 supply + 24,000 power, health 7,000; warhead stockpile 2 × (120 s, 1,500 + 40,000), aoe 150, edge 0.3, 8,000–10,000 damage, ~12.7 s flight at apex 300 (was 800; S-49); radar SAM interception chance 0.2 per burst (was 0.5; the user set it, S-50). My calls: strategic missiles are sent to every player wherever they fly, and the launch warning shows the silo's position. The AI doesn't build silos.
- **Missile stockpiles (S-47, the user asked through the client):** IR SAM missiles 6 s, 15 supply + 300 power; radar 12 s, 40 + 900; capacities Thorn / Vigil 8, Hornet / Halo 4, Wyvern / Aegis 6, Gorgon / Seraph 3 (the client's numbers; Halo mirrors Hornet). Naval SAMs stay unlimited (the user, through the client). AI effect not measured.
- **Archon radar signature 0.6 (S-46, the user asked through the client; was 0.35):** for your test in airsam.
- **Radar SAM range ×3 (S-45, the user asked through the client):** ranges 1680 / 1800 and the four units' radars ×3; projectileSpeed left at 360 (~5 s to full range); burn-through follows (35% of lockRange: ~600 studs now). AI and balance effects not measured yet. Also `climbHeight` 100 (S-44).
- **Radar SAM warheads (S-42, the user asked through the client):** `chs_radar_sam` and `ord_radar_sam` aoe 8 → 20 (bigger proximity fuse too), plus the vertical launch's pitch-over at 3× turnRate (`Guidance.PITCH_OVER`).
- **No hover unit in the roster (S-39):** the HOVER rules work (surface riding), but no def uses the class. Add one (e.g. a hover worker or tank per guide 6.1)?
- **Terrain speed factors (S-37):** placeholders in `Shared/Grid/Terrain.SPEED` (heavy tracked on sand 0.6, wheeled on road 1.25, ...; table in the guide, 12.1), and MapGen's painting rules (sand within 2 cells of water, rock above 15°; no roads). Both shape every generated map.
- **Carriers don't build aircraft (S-36):** the guide doesn't say they do; it would change the tech tree. Should they?
- **Pass 2 retune (S-30): `ord_verdict.sensors.sight` 140 → 170**, the one number changed this round. Three seeds, Verdict vs Hellmouth 0.50 / 0.58 → 0.50 / 0.97 (long fight in band); Verdict vs Ravager long 0.57 → 0.72. Overkill avoidance (S-29) didn't move artillery: without spotters both sides fire at sight range, so the Verdict's range and precision never applied. Still outside 0.8–1.25:
  - close-range artillery duel 0.50 (two artillery groups 120 studs apart: health and damage decide, where Chaos is tougher by design; closing it would cost faction identity);
  - Herald vs Jackal long 0.75 (close 1.06). Not touched, since one retune was asked for.
- **T1 ground balance pass** (S-22; tables in `docs/BALANCE.md`, "Balance passes"). Exact changes:
  - `chs_light_cannon.accuracy` 1.2 → 2.0 (also the Spike gun turret and the Mire amphibious tank);
  - `chs_ravager.cost` 130 / 1200 → 140 / 1400 (value 250 → 280; Lancer is 300);
  - `ord_light_cannon.range` 180 → 200 (also the Bulwark gun turret and the Tideguard amphibious tank);
  - `chs_hellmouth.cost` 160 / 1600 → 175 / 1750 (value 320 → 350; Verdict is 360);
  - `chs_mg.damage.LIGHT` 44 → 40 (Jackal only);
  - `chs_jackal.health` 340 → 320.
  - Results: Lancer vs Ravager 0.38 / 0.39 → 1.00 / 0.82; Herald vs Jackal 0.61 / 0.59 → 0.82 / 0.80; Verdict vs Hellmouth 0.55 / 0.73 → 0.61 / 0.80.
  - **Not reached: Verdict vs Hellmouth at close range (0.61).** No number moved it by more than 0.1. Likely cause: precise Verdict volleys overkill one target while mortar spread and blast share damage. Fix would be a mechanic (a group spreading its fire / overkill avoidance in Targeting). Do you want that?
  - **After S-23** (targeting stagger fix, three seeds): Lancer vs Ravager 1.26 / 1.00 (in band), Herald vs Jackal 0.91 / 0.71, Verdict vs Hellmouth 0.51 / 0.58. Artillery and the scouts' long-range fight need a second pass (and the artillery likely the overkill mechanic); not done, to avoid tuning on a moving base.
  - Side effects through shared weapons: Lancer vs Mire 1.36 / 1.57 → 2.39 / 2.04 (the Mire got the Chaos cannon's spread); Tideguard vs Ravager 0.27 → 0.53; Paladin vs Ravager 0.37 → 0.84 / 1.11.
- **AI tuning numbers** (S-7, S-17): placeholders, as agreed.

## For the client stream

- **Done (request 36), S-61, protocol 20:** State mask bit **128 OWNER**, after `stock`: `ownerMask u8` (QUEUE 1, STATES 2, AMMO 4), then:
  - QUEUE: `count u8`, `progress u8` (the head, 0..255), `defIndex u16` × count.
  - STATES: `u8` = fire (bits 0–1) + move × 4 (bits 2–3).
  - AMMO: `rounds u8`, `max u8`.
  - Owner only, each on change (queue progress by sixteenths) and with ENTER. Contract section 5.
- **Done (request 34), S-59:** Pinpointers `ord_witness` (Witness) and `chs_augur` (Augur).
  - Defs: T2 structures with icon family `pinpointer`, pieces `base` and `dish`, built by the Architect and Forgemaster, unit def field `pinpointer = true`.
  - Precision: `Shared/Combat/Pinpoint.precision(count)` = min(count, 6) / 6, where count is the team's finished Pinpointers. Error scales by `errorScale(p)` = 1 − 0.9 p.
  - No new record: count your team's Pinpointers from their icons, which are unique per unit type since S-58.
  - Contacts on the wire already arrive with the reduced wobble.
  - Radar vehicles: Oracle and Watcher (T1), Arbiter and Stalker (T2 fire control) already exist.
- **Done (request 35), S-58, protocol 19:** the Strategic record's icon is 8 bits (bits 0–7) and is the unit's **def index** (`Icons.byDef`): unique per unit type; team bits 8–10, flags bits 11–15 (5 bits, all in use). 0 = unknown blip as before. `def.icon` stays the family name (`Icons.names`). Still 6 bytes. Contract sections 3, 6.
- **Done (request 33), S-56:** SAM range and lockRange: IR 206 (Chaos) / 147 (Order), radar 945 / 1013. airSight Thorn 206, Vigil 157, Hornet 147, Halo 157; radars Wyvern 1013, Aegis 1097, Gorgon 810, Seraph 878.
- **Done (request 32), S-55:** SAM ranges and lockRanges: IR 294 (Chaos) / 210 (Order), radar 1260 / 1350. Sensors follow: airSight Thorn 294, Vigil 224, Hornet 210, Halo 224; radars Wyvern 1350, Aegis 1463, Gorgon 1080, Seraph 1170. projectileSpeed unchanged.
- **Changed (S-54, the user): `map:normandy` now fights west against east.** Player 1 is in the west rear (start (−850, 0)), player 2 in the east (850, 0).
  - **Coast:** sea, beach and bluffs (draws at x = −560, 0, 560) are a shared north flank (z > 560).
  - **South of z 560, mirrored:**
    - rear at |x| > 672;
    - rivers at x = ±660 with bridges at z = −700, −250, 250;
    - staging at |x| 420–640;
    - bocage at |x| < 400;
    - villages at (±220, −150).
  - **Your profile:** the `normandy` profile's zones need to move to this layout.
- **Done (request 31), S-53:** `map:normandy` (`Shared/Grid/Normandy`, via `MapRegistry.load`).
  - Your zones are all where you put them; layout in guide 5.5.
  - Hedgerows fill only z −200…280, so the strips at −360…−340 and 540…560 are open field.
  - Hedgerows (6 studs) and houses (8 studs) are ROCK cells; bluff cliff cells are ROCK too; roads and bridges are ROAD; sand is the beach and the river bed.
  - `Normandy.feature(cx, cz)` returns the feature name for drawing.
  - Starts: (0, 700) and (0, −700).
- **Done (request 30), S-52:** radar SAM weapons' stockpile capacity 15 (Wyvern, Aegis), buildTime 6 s per missile; Gorgon / Seraph stay at 3, IR SAMs and the cost per missile unchanged. Nothing on the wire changes.
- **Done (request 28), S-51, protocol 18:** `Shared/Combat/Lofted`: `Lofted.step(x, y, z, vx, vy, vz, gx, gy, gz, gy + weapon.apex, weapon.gravity, rad(weapon.turnRate) / 15, Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z)), 1/15)` per tick, and `Lofted.velocity(...)` for the arc from any point (preview, landing prediction). Phases from state: boost while vx = vz = 0 and climbLeft > 0; turn / arc while vy > 0; ballistic after. Strategic missiles arrive as **SPAWN_STRATEGIC 17** = SPAWN_PROJ fields + `goal pos` (25 B). Nukes: projectileSpeed 150 (boost), climbHeight 120, turnRate 90, gravity 12, apex 300 above the goal; 12.7 s. Guide 4.3, 7, 10.9; contract section 7.
- **Done (request 29), S-50:** `intercepts = { chance = 0.2 }` on both radar SAMs; drop the test override whenever you like. Request 28 (vertical climb for nukes) is next.
- **Done (request 27), S-49, protocol 17:** (a) `ord_nuke` / `chs_nuke` `apex` 300, `gravity` 15 (flight still 12.7 s); (b) STOCK entries are now `count u8, progress u8` (next missile's progress × 255, 0 when full), sent when a count changes or a progress crosses a sixteenth (`Stockpile.WIRE_STEPS`); animate at 1 / buildTime per second between records if you like. Contract section 5, guide 8.6 and 10.9.
- **Done (request 26: nuke silos and interception), protocol 16 (S-48):** silos `ord_reckoning` (Reckoning) and `chs_ragnarok` (Ragnarok), T3, icon `nuke`, built by Architect / Forgemaster; pieces `base`, `hatch`, `muzzle`. Warheads `ord_nuke` / `chs_nuke` (`strategic`, `manualFire`, `apex` 800, gravity 40, aoe 150, stockpile 2 shown with STOCK like the SAMs). Fire with ATTACK_GROUND on the silo: one launch per order. New events: **INTERCEPTOR 14** (SPAWN_PROJ layout; `targetId` = the chased missile's **projId**), **LAUNCH_WARNING 15** (`projId, pos` of the launch; every player, camera or not), **INTERCEPTED 16** (`projId, pos`: destroyed in flight, no detonation; instead of IMPACT). A strategic missile's SPAWN_PROJ goes to every player wherever it flies (step it with the weapon's gravity; it lands where ordered); its IMPACT is the detonation. Guide 4.3, 8.6, 10.2, 10.9 (new), 11.5, 13.5, 7; contract section 7.
- **Done (request 25: missile stockpiles), protocol 15 (S-47):** State records gain **STOCK, mask bit 64**: `slotMask u8` + `count u8` per set bit, after `targets`. Only weapon slots with a stockpile are set; capacity is `defs.units[id].weapons[i].stockCapacity` (Shared defs; weapon field `stockpile = { capacity, buildTime, cost }`, slot override `stockpile = n`). Sent to the owner only, whenever a count changes and with every ENTER. Capacities: Thorn / Vigil 8, Hornet / Halo 4, Wyvern / Aegis 6, Gorgon / Seraph 3; naval SAMs none. Scenario spawns start full; built and produced units start empty. Guide 4.3, 4.5, 8.6 and contract section 5 updated. Request 26 (nuke silo) next.
- **Done (request 24), S-46:** `ord_archon` radarSignature 0.35 → 0.6 (Phantom unchanged at 0.2).
- **Done (request 22: a longer vertical climb), S-44:** weapon field `climbHeight` (100 on both radar SAMs). Step vertical launches with `Guidance.vertical(..., turned, climbLeft)` and `climbLeft = Guidance.climbLeft(weapon, y, Layers.heightAt(layers, x, z))`: while the missile flies exactly straight up (vx = vz = 0) and `climbLeft > 0` it doesn't steer. Ground height: `Layers.heightAt` (Shared, cell-based; the server's `Combat.groundHeight` now calls it), not a smoothed ground. No age needed. Contract section 7.
- **Done (request 23: radar SAM range ×3), S-45:** `chs_radar_sam` 1680, `ord_radar_sam` 1800 (range and lockRange); radars Wyvern 1800, Gorgon 1440, Aegis 1950, Seraph 1560. projectileSpeed stays 360.
- **Done (request 21: projectiles regardless of sight), protocol 14 (S-43):** SPAWN_PROJ (at launch), homing corrections and IMPACT now go to every player whose camera area (+ margin) has the projectile, seen or not; `targetId` as before. Gun shots of a shooter you don't have arrive as the new **SHOT 13**: `hit u8, start pos, end pos` (14 B), no IDs; draw the tracer from start to end. Shots of shooters you have stay FIRE. Cloak isn't built; the guide (11.4) records that firing drops it. Guide 7.2 / 7.3 and contract section 7 updated.
- **Done (request 20: vertical-launch radar SAMs, heavy warheads), S-42; supersedes request 12.** `chs_radar_sam` and `ord_radar_sam` have `launch = "vertical"` and `aoe` 20 (damage unchanged). The launcher fires with no turret aim (the turret stays at rest; aim State records don't change); SPAWN_PROJ carries the missile at the muzzle with an upward velocity. **One change on your side:** steer missiles of `launch == "vertical"` weapons with `Guidance.vertical(..., turned)` and keep `turned` per missile (false at SPAWN_PROJ), not `Guidance.pn`: the climb turns at 3× turnRate toward the target until it is within 15° of the nose, then PN. Contract section 7.
- **Done (requests 17–19), S-38:** jets now fly to their move goal and arrive within `Air.ARRIVE_RADIUS` (40 studs) or at the closest approach for a goal inside their turn circle, then circle at `Air.LOITER_RADIUS`; DECOYED ends with `countermeasure u8` (1 flares, 2 chaff, 3 DIRCM; protocol 13, 23 B); aircraft shot down in flight leave no wreck (DEATH `wreckId` 0). Note: the Falcon and the Guardian have DIRCM, not flares.
- **New (S-37): terrain types.** `Layers.terrain` (u8 per cell: `Layers.Terrain` GRASS 0, ROCK 1, SAND 2, ROAD 3) comes with every map from `MapRegistry.load`; generated maps paint sand on shores and rock on steep ground. Units are slower on sand and rock (factors in `Shared/Grid/Terrain.SPEED`), so the client can colour the ground and predict speeds with `Terrain.factor`. Nothing changes on the wire.
- **New (S-35): CANCEL command 16** (protocol 12): on an unfinished frame it cancels it with a refund; on a factory it drops queue item `value` (0 = all). Contract section 9.
- **New (S-34): move states work.** Idle Fire-at-Will units on Maneuver (default) chase visible enemies near their spot and walk back; Roam chases farther; Hold Position stays. The orders aren't replicated; units just move.
- **New (S-36): carriers.** GUARD from an aircraft on a friendly carrier or airfield lands it there and keeps it docked (LANDED, moving with the carrier) until any order launches it.
- **Done (request 16: Thorn range and blast), S-33:** `chs_ir_sam` range / lockRange 420, aoe 12 (also the fuse), projectileSpeed 500; `chs_thorn` airSight 420 (an IR site only locks what it sees). Everything is read from the defs.
- **Done (request 14: MOVING), S-33:** set on ground and naval units with a movement order or speed and on aircraft unless landed (loitering included), cleared when they stop; it arrives in State records like any bit.
- **Partly done (request 15: past the map's edge), S-33:** projectiles that leave the map burst on its edge (an IMPACT there), so missiles no longer fly on past it. Aircraft are unchanged: keeping jets inside by turn radius broke bombing runs on small maps; they still turn back at 60 studs (your measurement: up to 14 studs out). If that matters, the alternative is positions past the edge on the wire (signed offsets, a protocol bump); say if you want it.
- **Done (requests 9 and 10: sight map and wrecks), protocol 10 (S-26):** four new **Events** kinds, so no new remote: `SIGHT_ROWS 11` (the whole map as a bitset, after WELCOME), `SIGHT_CELLS 12` (changed sensor cells, bit 15 = now in sight, on sensor ticks), `WRECK 9` (`wreckId, defIndex, cell, offX, offZ, heading`), `WRECK_GONE 10`. The sight is the ally team's LOS (allies' units included), so the fog can drop its own sight rebuild; wrecks are known like ghosts (seen once, gone only when the team sees the empty spot), map-wide for the minimap; DEATH's `wreckId` still links the death to its WRECK in the same batch. Spectators: no sight records, every wreck. Contract section 7a. Cost: ~0.5 KB/s per player at 800 units, a join ~2 KB.
- **Done (request 13d: decoyed missiles turn gradually), protocol 11 (S-28):** no more 60° one-tick veer. A decoyed missile follows a decoy point for up to 1 s at its `turnRate` (`Guidance.decoy`), then flies straight. The point is 25 studs **across the missile's flight path** (not behind the target: in a tail chase that point lies on the missile's line and decoyed missiles still hit) and below the target for flares. DECOYED now carries the point and the ticks left (22 B), so the client steers it like the server (under a stud apart in `Guidance.spec`). The roll comes 20–60 studs out, so the bend is short (10–20°). Contract section 7.
- **Done (request 13: IR SAMs missing), S-27:** missiles steered at the target's end-of-tick position from their start-of-tick position (a one-tick lead); they now fly proportional navigation from `Shared/Combat/Guidance` against the step-start position, and an IR / RADAR seeker cone (60° / 70°, weapon field `seekerAngle`) breaks the lock on an overshoot (LOST_LOCK, no second pass). Thorns vs a circling Falcon: 90% hits (was 33%); every miss is a flare decoy. No `fuseRange`: not needed once the aim is right. No G limit: at constant speed `turnRate` is one. **Request 11b (shared aim):** `Guidance.pn` / `Guidance.lead` are the server's steering; call them with the target's position before this tick's records and its velocity (contract section 7). `Combat.aimPoint` itself is still server-side.
- **Ready:** `docs/contracts/net.md` (network contract). Merged into `main`.
- **Ready:** protocol 6 is built: join / reconnect (`NetOut.hello`, `NetOut.join`) and the Eco channel (the client-state contract's economy placeholder can use it). Contract section 10.
- **Ready:** all commands now work (S-4, contract section 9): shift-queue, FIGHT, PATROL, ATTACK, GUARD, REPAIR, RECLAIM, BUILD, factory rally (move-like order on a factory) and repeat (TOGGLE on a factory). Order queues aren't replicated; draw queued paths from what the client sent.
- **Done (request 2: unit state bits in Shared):** `Schema.UnitState`; `World.State` is that same table (S-6). On `main`.
- **Protocol 9 (S-21):** Eco records start with `team u8` (36 B). Players still get one record, their own team's; spectators get every team's in one message. A client that reads the first record keeps working; a spectator view should key economies by `team`. Contract section 10.
- **Done (request 8: Juggernaut arm timing, S-20):** turret `restYaw` / `restPitch` / `restoreDelay` in the weapon defs; weapons start at rest, rise before they can fire, hold for the delay, then return to rest. The Juggernaut has its own `chs_juggernaut_cannon` (rest -65°, 80°/s, 3 s) and `armL` / `armR` in its pieces. `Shared/Combat/Aim.update` is the server's exact step: a client running it from the rest pose with the same wanted aims gets the server's angles bit for bit (`Aim.spec`).
- **Done (request 7: shorter build ranges, S-19):** 56 (Command Vehicles), 45 (constructors), 34 (aircraft builders). A builder now starts a frame only in range of its snapped center.
- **Done (request 6: own units' weapon targets), protocol 8 (S-16):** State records carry `targets` (mask bit 32: slot mask + `targetId u16` per slot, 0 = none) for the player's own units, on every change and on ENTER when there is a target; never to other players. `NetOut.spec` checks the owner's view equals the sim's targets every tick. Contract section 6.
- **Procedural maps (S-15):** `MapRegistry.load("map:ridgeline" | "map:coastline" | "map:twin_lakes" | "map:crossroads")` or `"mapgen:<layout>:<seed>:<cells>[:<water>]"` gives the usual `Layers`, so the client renders them like any map; `MapRegistry.info(id)` has the player count and mode tags. On 2v2 maps starts 1–2 are one team. Generation takes ~0.1–0.3 s (including its checks).
- **Attack-move (S-14):** a FIGHT / PATROL move now holds only while an enemy is within a weapon's firing range (BAR); `orders` isn't replicated, so nothing changes on the wire.
- **Protocol 7 (S-13):** new command `REPEAT 15` (value 0 / 1) for factory repeat, and the factory's `REPEAT 16` state bit shows it. TOGGLE on a factory no longer sets repeat; a repeat button should send REPEAT. Contract sections 3 and 9.
- **Done (request: formation slots in Shared):** `Shared/Grid/Formation`: `SLOT_SPACING`, `spacing`, `spiral`, `layout` (with optional `ground = { open, snap }` callbacks), `deepestFirst`, `assign(posX, posZ, members, slots)`. `Nav` uses it, and `Formation.spec` shows a client prediction from it alone equals the server's goals for line, spot and aircraft moves on open ground, so `Core/Orders.lineSlots` can call it instead of its copy (S-12). Contract section 9 lists the steps.
- **Done (request 1: bomber weapon pieces, revisited):** S-3 only added `bay` to `pieces`; bombs have no turret (they fall from a fixed bay, D91), so the four bombers now drop `turretPiece` and keep only the muzzle, and `Defs` rejects a turret or pitch piece on a turretless weapon (S-11). The hull-muzzle workaround can go.
- **Done (request 5: icon numbering in Shared):** `Shared/Net/Icons`: `Icons.names(defs)`, `Icons.byDef(defs)`, `Icons.MAX`. `NetOut.iconIndex` is `Icons.byDef`, and a test checks the server sends exactly those numbers, so `Core/Icons` can call it instead of its copy (S-10). Contract section 3 points to it.
- **Done (request 4: placement rules in Shared):** `Shared/Grid/PlacementRules` has `snap`, `terrainOk(passMap, cell, placement)` and `LAND_MAX_SLOPE`, `WATER_MIN_DEPTH`, `RADIUS_PER_FOOTPRINT`. The server's `Placement`, `Nav` and `Combat` use it, and a test checks the server's terrain verdict equals it, so the client copy (C-14) can go (S-9). Occupancy and units in the way stay server-side.
- **Done (request: bomber weapon pieces):** all 14 defs with a weapon piece missing from `pieces` are fixed (not only the bombers), and `Defs` validation now rejects such defs (S-3). On `main`.

## Integration notes

Merges into `main` done by this session (the integrator). Failures and conflicts are recorded here, per stream.

- 2026-10-21: client `a2371cd`, `f815a5d`, `7bbaa7b`, `89e7db1` merged (`--no-ff`); `lune run test` 34 specs / 253 passed, `lune run build` 263 scripts / 787 requires; pushed (`2a8b078`). `main` merged into `m-sim-2`.
- 2026-10-21: client `a96cca2` (contracts: rig, blockout format, client-state draft) → `02bacbc`; `2062b10` (blockout generator) → `4c93177`; `df29a2d` (client foundation) → `6b05efe`. Each passed test and build and was pushed; `main` merged back into `m-sim-2`. No conflicts or failures.
- 2026-10-21: client `f52bf53` → `f649cfe`; `47aaa63` → `cbd662e`. Both passed test (36 specs / 270) and build (297 scripts / 894 requires) and were pushed; `main` merged back into `m-sim-2`. No conflicts or failures.
- 2026-10-21: client `afe8aea` (combat effects) → `4c00545`; `b8405ff` (strategic zoom icons) → `a1dbd54`. Both passed test (36 specs / 271) and build (302 scripts / 914 requires) and were pushed; `main` merged back into `m-sim-2`. No conflicts or failures.
- 2026-10-21: client `508b215` (placeholder minimap and resource bar) → `425c468`; `002cc39` (client night summary) → `a1c2740`. Both passed test (36 specs / 272) and build (306 scripts / 929 requires) and were pushed; `main` merged back into `m-sim-2`. No conflicts or failures.
- 2026-10-21: client `90c387d` (client uses Shared PlacementRules and Net/Icons) → `ea959dd`; `5563c15` (readable shells, effect diagnostics) → `64eab13`. Both passed test (36 specs / 272) and build (306 scripts / 932 requires) and were pushed. Merged before S-12 so that marking request 3 in `docs/progress/client.md` sits on top of the client's own edits to that list. No conflicts or failures.
- 2026-10-21/22: client `6cff90b` (line-move goals from Shared Formation) → `af5c58a`; `142b5c6` → `b9ba305`; `3e2066b` → `dc7d42b`; `b207ca1` (extractor deposits, C-22) → `5798486`. Each passed test and build and was pushed.
- **2026-10-22, not merged: `486fc51` (queued builds, C-23) conflicts** in `docs/progress/client.md`, so the merge was aborted and nothing was pushed. Cause: the sim session marked request 6 done in the client's request list (`f5b8093`, "Mark client request 6 done (S-16)"), and `486fc51` adds request 7 directly above that line. Resolution: keep both lines (request 7 as the client wrote it, and request 6's "Done (S-16…)" prefix). The next merge of `main` into `m-client-foundation` will show it; after that the 8 waiting commits (`486fc51`, `2fa0039`, `9abe9b0`, `f5740e0`, `a602502`, `9254e74`, `f95efcc`, `49e983c`) all build on `486fc51` and stay blocked until then. The sim session won't edit the client's progress file again; it reports "done" in its own file instead.
- 2026-10-22: merges now run in the integration worktree `../FTGG-integration` with `tools/integration/integrate.sh` (see `CLAUDE.md`, "Integration"). The client resolved the `486fc51` conflict in its merge `dfdd0e7`; integrated `dfdd0e7` (client commits `486fc51`..`49e983c`, C-23..C-30) → `870357e` and `e125dee` (air and naval rendering, C-31) → `0494564`. Both passed test (39 specs / 292) and build (326 scripts / 1004 requires) and were pushed. Nothing blocked.
- 2026-10-22: client `4a014e9` (C-39), `3671f2b` (C-40), `d8f67eb` (request 13), `272b106` (merge of `main`), `486d468` (SAM scene), `b3c1d19` (C-41) → up to `c594a2d`; each passed test (41 specs / 299) and build (339 scripts / 1058 requires) and was pushed. No conflicts or failures.
- 2026-10-22: client `849486c` (merge of `main`), `f9cc4ed` (C-42), `7c2180c` (SAM scene), `64472f6` (C-43), `d44e70c` (request 13d) → up to `4855ea2`; each passed test (42 specs / 304) and build and was pushed. No conflicts or failures.
- 2026-10-22: client `7a7e2bd`, `8ca419a` (C-44), `4346a86` (C-45), `2d244af` (C-46), `d39ec8e`, `58187a7` (requests 14–16), `927a141` (C-47) → up to `9a334b5`; models stream `84ba52d` (T1 blockouts, M-1..M-5) → `3f11cf6`. Each passed test (44 specs / 313) and build and was pushed. The models stream (`m-models`, `docs/progress/models.md`) is new; its commits touch only `src/shared/Defs/Blockouts/` and its own progress file.
- 2026-10-22: client `a8d794e`, `91a79a1` (C-48), `37c6142`, `1ae6176` (C-49) → up to `100daff`; models `255dd9f` (M-6..M-8) → `1480dfa`. Each passed test and build and was pushed. No conflicts or failures this round.
- 2026-10-22: client `073d5e7` (C-50) → `051456b`, passed test (47 specs / 327) and build, pushed. Then `m-sim-2` (S-38..S-40) → `dceb4fa`; that merge ran the old `integrate.sh` (fast suite and build), so the slow suite was run on `main` afterwards: 6 passed.
- 2026-10-22: client `5c92bb0` (C-52) → `0a5f17b`; `d39244e`, `ad0c3b1` (request 21) → `8492ee2`; `6cafe85`, `9698380` (C-54, SHOT tracers) → `d4b8dab`. All passed test, test_slow and build and were pushed. `check.sh` read only the first commit of a "Ready to merge" line, so it missed `9698380`; it now lists every commit on such a line.
- 2026-10-22: client `95ff932` (main with S-44, S-45) → `9bf4948`, `8b54138` (C-55, the climb mirrored on the client) → `dd72f27`; both passed test, test_slow and build and were pushed. Both were on one "Ready to merge" line, which the fixed `check.sh` lists.
- From S-40 on, `integrate.sh` also runs the slow suite (`lune run test_slow`) before pushing.
- Own merges (`m-sim-2` → `main`, same checks): S-1 `c81f8b3`, S-2 `baaa520`, S-3 `a7c2fb6`, S-4 `b56a695`, S-5 `eab1900`, S-6 `46e31e3`, S-7 `f49e64d`, S-8 and S-9 `bb009c5`, S-10 `7d9be6f`, S-11 and S-12 `c64e3e0`.

## Overnight 2026-10-21 (integrator + queue)

- Task 1 ✅: `docs/contracts/net.md`; `Ballistics` (with `steer`) moved to `Shared/Combat` for the client (S-1).
- Task 2 ✅: join / reconnect snapshot and the Eco channel, protocol 6 (S-2). Tests: **34 specs, 257 passed**.
- Client request ✅: weapon pieces in `pieces` and a validation rule (S-3).
- Task 3 ✅: order queues and behaviors (S-4): shift-queue, FIGHT holds to engage, PATROL, ATTACK, GUARD, REPAIR (free healing), RECLAIM / BUILD queues, factory rally and repeat. `Orders.spec` (8 tests). Tests: **35 specs, 265 passed**.
- Client request 2 ✅: `Schema.UnitState` (S-6).
- Task 5 ✅: smarter AI (S-7): radar tower, Advanced Vehicle Plant with a fire-control radar escorting waves, kiting artillery, IR SAM trucks and sites against known aircraft. `AI.spec` (4). Tests: **36 specs, 270 passed**.
- Task 6 ✅: `lune run soak`, 40-minute AI-vs-AI match test (S-8).
- Client request 4 ✅: placement rules in Shared (S-9). Tests: **36 specs, 271 passed**.
- Client request 5 ✅: icon numbering in Shared (S-10). Tests: **36 specs, 272 passed**.
- Client request 1 revisited ✅: bombers without turret pieces (S-11). Client request 3 ✅: formation slots in Shared (S-12). Tests: **37 specs, 275 passed**.
- Task 4 ✅: Movement peak at 800 units 12.1 → 6.4 ms (budget 10): field extensions are sliced Pathing jobs, and the corridor merge is bounded (S-5). Stress: average tick 8.6 ms, Pathing peak 8.4 ms.

## Summary (end of round 8, 2026-10-20; merged into `main` as `sim-headless-v0.2`)

**Done:** all five round-8 answers, one commit each, then the merge.

| Item | What | Commit |
|---|---|---|
| 1, 3 | Pathfinding on the real map is physics (D106); blast weapons and tracking recorded as M8 item 2 in `BALANCE.md` | `d90b307` |
| 2 | Untracked radar contacts reveal only their domain (D107) | `cb5c8fc` |
| 4 | Jammer power upkeep: the jam radius shrinks in a power stall (D108) | `32e99fb` |
| 5 | Unit generations and ghost pins for ID reuse (D109) | `26e612a` |
| — | Balance re-run, progress files split (`docs/progress/`), merge | (last commits) |

**Tests:** `lune run test` gives **34 specs, 253 passed, 0 failed** (245 at the end of round 7). New: `IdReuse.spec` (4 tests) and tests in `Knowledge.spec` (3) and `Fog.spec` (1). Each fails when its mechanism is undone.

**Results:**
- **Domain-only contacts:** untracked blips show air, surface or submerged only. Type priorities apply only to visible, remembered or tracked targets (a Seraph now picks the nearer untracked blip and the jet once tracked). The AI follows the same rule.
- **Jammers:** they drain 15–35 power per second (placeholders), and their radius shrinks with the share of power they get. The tracking-radar mechanism now covers both (`powerScale`).
- **ID reuse:**
  - every remembered unit reference carries the unit's generation: weapon targets, last attacker, rearm pads, builder targets, projectile shooters and homing targets, ghosts, NetOut's tactical set;
  - IDs remembered as ghosts are pinned and never reused, so wire IDs stay unique.
- **Counter check** (2 seeds): 457 of 568 pairs hold, 192 findings (49 mechanic, 143 numbers). Same-role band 34 of 38.

**Open questions:** none from this round. Earlier open points are settled: pathfinding is physics (D106); radar contacts reveal only their domain (D107).

---

## Launch items (not built yet)

- **Replay compression** (the user, 2026-10-22: note it, don't build it yet). Player replays (`Shared/Net/PlayerReplay`, "FTGP") are raw: a spectator recording runs ~420 KB per game minute at ~240 units (16.8 MB for the 40-minute soak), a player's ~33 KB per minute on a small 4-minute match. Before launch, where replays are stored or shared:
  - measure first: deflate / zstd-class compression of whole files vs. per-frame, on the soak's spectator recording and a player's;
  - cheap wins inside the format: delta-encode Tactical records against the unit's previous record, drop redundant tick headers inside a frame, run-length the Strategic snapshots (mostly unchanged every 5th tick);
  - it plugs in at `PlayerReplay.serialize` / `parse` (a new format byte, version 2), so recorders and players stay the same; Roblox has no built-in compressor, so a pure-Luau one (or a server-side store that compresses) is the likely path.

## How to continue

- Branch: `m-sim-2` (pushed to `origin`); merged into `main` after every task. Run `lune run test` from the repo root (~65 s); everything must pass before starting the next task.
- **Integration:** merges into `main` run in the worktree `../FTGG-integration` with `bash tools/integration/check.sh` and `bash tools/integration/integrate.sh <commit> "<description>"` (`CLAUDE.md`, "Integration"); never in this checkout, and never edit `docs/progress/client.md`.
- **Next:** the answers under "Needs my review", then the gaps from the guide coverage audit above (move states, line of fire, terrain types, amphibious and hover, carriers, cancel), by importance.
- Rules: `CLAUDE.md`, the `ftgg-roblox-dev` skill and the design guide (`docs/For_The_Greater_Good_Design_Guide.md`).
- Unattended-session rules (from the user):
  - After each task passes the tests: commit, push, and update this file.
  - When something is unclear, decide, log it in `docs/decisions/sim.md` (prefix `S-`) and continue.
  - Stop only if a test can't be made to pass, or a change would delete or rewrite existing work.
  - Never weaken a test to make it pass.
  - Simulation code only: nothing that needs Studio.
  - Debug output goes in `debug_out/`, which is gitignored.

## Task list

| # | Task | Status |
|---|---|---|
| 1 | Packer/Schema follow-ups (8 weapon slots, PROTOCOL_VERSION, BUILD facing, tick wrap), guide 0.4 | ✅ done (`e1be1c4`) |
| 2 | Defs: loader, `extend`, validation (4.5), indices, hash, enums, `ord_lancer` / `chs_ravager` | ✅ done |
| 3 | Grid: cell math, position encode/decode, procedural test map (height + water) | ✅ done |
| 4 | World (SoA, u16 IDs with delayed reuse, dirty bits), `Sim.step` with stub systems, replay log, world hash | ✅ done (M0 exit criteria met) |
| 5 | Movement classes and passability: passMask + per-class clearance on the test map | ✅ done |
| 6 | Quadtree + coarse A* route + corridor | ✅ done |
| 7 | Flow field (integration + direction), LRU cache, time-slicing, PPM debug image | ✅ done |
| 8 | `lune run bench`: flow field timings on 256×256 (open, maze, island) vs 8 ms budget | ✅ done (over budget, see Benchmarks) |
| 9 | Movement and local avoidance: shared fields, separation, arrival, line-move spreading | ✅ done |
| 10 | Combat core: targeting, aim model, HITSCAN/BALLISTIC, projectiles, damage, AoE, deaths | ✅ done |
| — | Rules review (requires, determinism, no Instances, hot-loop allocation) | ✅ done |
| — | Round 3: direct-path shortcut, bucket-queue flow fields, duel reports | ✅ done (`bafe3b1`–`8878849`) |
| M3 | Economy and construction (headless), scripted T1 build order, M3 review | ✅ done (`3c27b99`–`1b17519`) |
| 11 | Sensor maps, visibility levels, ghosts (M4) | ✅ done |
| 12 | Wobble, jamming, stealth, fog-aware targeting (M4) | ✅ done |
| 13 | Interest management and NetOut, simulated client | ✅ done |
| 14 | Stress test and bandwidth report | ✅ done |
| 15 | Air: jets, helicopters, ammo, rearm pads (M6) | ✅ done |
| 16 | Naval: ships, subs, torpedoes (M6) + M6 review | ✅ done |
| 17 | Electronic warfare (M7) + M7 review | ✅ done |
| — | `docs/STUDIO_HANDOFF.md` | ✅ done |

## Done so far

### Task 2 — Defs

- `src/shared/Defs/`:
  - `Defs.luau`: validate, build, load, hash.
  - `Templates.luau`: `extend`, `Unit`, `TankT1`.
  - `Registry.luau`, plus `Categories`, `ArmorClasses` and `MoveClasses`.
  - `Units/ord_lancer`, `Units/chs_ravager`, `Weapons/ord_light_cannon`, `Weapons/chs_light_cannon`.
- `src/shared/Util/Hash.luau`: FNV-1a 32 plus a canonical value hash.
- Specs: `Defs.spec` (valid load, indices, derived values, extend, freeze, hash, missing damage logged, 28 broken-def cases, aggregated errors) and `Hash.spec`.
- Tests: **6 specs, 51 passed, 0 failed**.
- Decisions: D1–D7 in `docs/DECISIONS.md`.

### Task 3 — Grid

- `src/shared/Grid/`:
  - `Grid.luau`: 8-stud cells up to 256×256, centered on the origin; index/coords, cellAt, cellCenter, encode/decode (error in [0, 1/32) stud, clamped to the map), 16-stud sensor cells.
  - `Layers.luau`: height and waterDepth as i16 in 0.25-stud steps.
  - `TestMap.luau`: seeded 3-octave value-noise hills with water below sea level, plus `build()` for hand-made maps.
- `.lune/lib/Ppm.luau` (PPM and PNG writer) and `.lune/debug_map.luau`. `lune run debug_map [seed] [cells]` writes `debug_out/map_<seed>.png`.
- Specs: `Grid.spec` (sizes, index round-trip, boundaries, 15,000 random encode/decode round-trips within 1/32 stud, clamping, sensor cells) and `TestMap.spec` (quantization, determinism per seed, water consistency, 256×256).
- Tests: **8 specs, 64 passed, 0 failed**.
- Decisions: D8–D12.

### Task 4 — World, Sim, replay

- `src/server/Sim/`:
  - `World.luau`: SoA fields, dense `ids` list, fresh-first IDs with FIFO reuse after 150 ticks, dirty-bit setters, hash.
  - `Sim.luau`: `new`/`submit`/`step`/`hash`/`fromReplay`/`runReplay`; 11 systems in guide order with rates and Profiler labels; checkpoint every 300 ticks.
  - `Replay.luau`: binary log with header, COMMAND and CHECKPOINT entries.
  - `Scenarios.luau` (`empty`, `skirmish_test`), `Types.luau`.
  - `Systems/Commands.luau`: applies fire state, move state and toggle to the sender's own units. The other 10 systems are stubs.
- `Packer` gained `writeString`, `readString` and `readBuffer`.
- Specs:
  - `World.spec`: dense ids, delayed FIFO reuse after exhausting all 65,535 IDs, dirty bits, order-independent hash.
  - `Replay.spec`: round-trip, every truncated prefix, bad magic/format/kind.
  - `Sim.spec`: system order; 1,000 ticks twice give identical checkpoints and hash; a different seed differs; replay reproduces the run and re-records an identical log; an injected command and a corrupted checkpoint are both caught; protocol/defs mismatch refused; malformed submits dropped; ownership respected.
- Tests: **11 specs, 83 passed, 0 failed**.
- **M0 exit criteria met.** CLAUDE.md's milestone line now says M1.
- Decisions: D13–D20.

### Task 5 — Passability

- `src/shared/Grid/Passability.luau`: `build(layers)` produces:
  - the slope layer (u8);
  - passMask (u16, bit per move class: ford/slope for land, depth for ships and subs, any water for hover, slope only for amphib, air always);
  - per-class clearance (Chebyshev distance transform, map edge counts as blocked).

  Plus `canEnter`, `clearance`, `fits(moveClass, footprint, cell)` and `requiredClearance(F) = floor(F/2) + 1`.
- About 75 ms per 256×256 map in Lune (load time only).
- Specs (`Passability.spec`):
  - an exact slope value;
  - a depth table across all 9 classes (ships only on deep water, subs deeper, ford limits);
  - a 26.5° ramp that blocks HEAVY_TRACKED, WHEELED and HOVER but not TRACKED or AMPHIB;
  - exact clearance on a hand-built map;
  - a footprint-2 unit rejected in a 1-cell gap and accepted in a 3-cell gap;
  - generated-map invariants and the Lipschitz property of clearance.
- Tests: **12 specs, 92 passed, 0 failed**.
- Decisions: D21–D24. **D21 changes the guide's footprint formula. Please confirm.**

### Task 6 — Quadtree and coarse route

- `src/server/Sim/Path/`:
  - `Heap.luau`: deterministic (k1, k2, id) min-heap, reusable.
  - `Quadtree.luau`: per (move class, need); summed-area uniformity; edge-sharing neighbors; components.
  - `Route.luau`: A* over leaves with failure reasons, plus `corridor()` (route leaves + adjacent open leaves, mask buffer + bounding box).
- Measured on 256×256 hilly terrain: tree about 6 ms (4,285 leaves, 2,413 open); corner-to-corner route about 2.5 ms (40 leaves); corridor 0.15 ms (20,545 cells).
- Specs (`Route.spec`):
  - heap ordering;
  - flat 256² collapses to 1 leaf, 200×120 to ≤ 64 leaves, generated terrain < 1/4 of cells;
  - partition, symmetric neighbors, and components identical to cell flood-fill;
  - a route around a wall goes through the gap, with consecutive leaves touching and the goal reachable inside the corridor;
  - island, blocked goal and blocked start fail with the right reasons;
  - a 1-cell gap passes footprint 1 but not footprint 2;
  - a same-leaf route; determinism.
- Tests: **13 specs, 99 passed, 0 failed**.
- Decisions: D25–D28.

### Task 7 — Flow fields

- `src/server/Sim/Path/FlowField.luau`:
  - a job runs Dijkstra from the goal over corridor cells (8-connected, √2 diagonals, no corner cutting), then a direction pass (u8, 255 = none);
  - `run(job, budget)` is time-sliced in work units and resumes exactly;
  - plus `build`, `direction`, `covers`, `vector`.
- `src/server/Sim/Path/FieldCache.luau`: LRU (default 32) keyed by `moveClass:need:goal`; hit/miss/eviction stats; `invalidateCell`.
- `.lune/debug_flowfield.luau`: `lune run debug_flowfield [maze|hills] [seed]` writes `debug_out/flowfield_<kind>.png` (cost shading plus direction ticks).
- `src/server/Tests/Support/Maps.luau`: shared test map builders (flat with water, zig-zag maze, field from start to goal).
- Specs (`FlowField.spec`):
  - from every corridor cell, following the field reaches the goal without leaving the corridor or cutting corners (wall map, maze, generated terrain);
  - integration equals the octile distance on open ground;
  - the pinch-corner case;
  - sliced output equals one-shot for budgets 1, 7, 64 and 1000;
  - vectors; cache hits, LRU eviction and invalidation.
- Tests: **14 specs, 107 passed, 0 failed**.
- Decisions: D29–D32. **D29 (work-unit budgets) changes how guide 6.4's "8 ms" is enforced. Please confirm.**

### Task 8 — Benchmark

- `.lune/bench.luau`: `lune run bench [runs]` times passability, quadtree, route, corridor and flow field on 256×256 open/maze/island maps (west-to-east endpoints, TRACKED, footprint 1). It prints a table and writes `debug_out/bench.txt`.
- Results below. No optimization was done, as instructed.
- Tests: unchanged (**14 specs, 107 passed**).
- Decision: D33.

### Task 9 — Movement and local avoidance

- `src/shared/Grid/MapRegistry.luau`: `none`, `flat:<n>`, `wall:<n>`, `gen:<seed>:<n>`. The sim loads its map from `mapId` (D34).
- `src/server/Sim/Nav.luau`: movement profiles, lazy quadtrees, field cache, the job FIFO, move orders with group fields and per-unit slots (spiral formation or line), goal snapping, field extension, and line-of-sight checks.
- Systems:
  - `Pathing`: runs field jobs within 12,000 work units per tick.
  - `Movement`: steer, move with terrain sliding, overlap resolution, write-back with dirty bits.
  - `Commands`: MOVE/FIGHT/PATROL (with LINE) and STOP now have effects.
- `World` gained movement fields (speed, orderId, goal, direct, progress), all hashed. `Route.findMany` and `Route.mergeCorridors` were added. Scenario `march_test` places 50 Lancers on the west side.
- `.lune/debug_movement.luau`: `lune run debug_movement [mapId] [ticks]` writes `debug_out/movement_<map>.png` with tracks and prints arrival statistics.
- Specs (`Movement.spec`):
  - 50 units cross a lake map, and 50 units detour through a wall's gap: all finish within 2,000 ticks, end ≤ 24 studs from their slots on open ground, and overlap at most 0.5 stud;
  - one order shares one field with distinct slots;
  - same seed gives identical positions and hash, and the replay reproduces it;
  - line-move goals are evenly spaced end to end, and units reach them;
  - a water goal snaps to land;
  - STOP; out-of-map cells are ignored;
  - idle units stay clean (no dirty bits).
- Tests: **15 specs, 115 passed, 0 failed**.
- Bugs found and fixed: the job FIFO used `table.insert` on a queue with nil head slots, so extension jobs never ran. Arrived units were shoved away by later arrivals.
- Decisions: D34–D42.

Movement results (`lune run debug_movement`, 50 Lancers west → east, Lune on the dev PC):

| map | ticks to all arrived | sim ms/tick | fields built | units ≤ 2 studs from slot | worst distance from slot | closest pair gap at end |
|---|---|---|---|---|---|---|
| gen:7:96 | 461 | 0.18 | 2 | 34/50 | 13.7 | −0.00 |
| gen:3:96 | 404 | 0.18 | 1 | 47/50 | 6.3 | +0.07 |
| gen:11:128 | 532 | 0.17 | 1 | 45/50 | 5.3 | −0.00 |
| gen:21:128 | 628 | 0.17 | 2 | 33/50 | 11.7 | −0.20 |
| gen:5:96 | 477 | 0.17 | 1 | 27/50 | 7.3 | −0.00 |
| flat:64 | 312 | 0.14 | 1 | 45/50 | 14.0 | −0.00 |
| wall:64 | 431 | 0.18 | 5 | 25/50 | 5.8 | −0.00 |
| wall:96 | 597 | 0.20 | 5 | 32/50 | 16.5 | −0.00 |
| wall:128 | 757 | 0.24 | 6 | 26/50 | 14.8 | −0.00 |

Every unit arrives on every map and overlap is negligible. Formation precision is mediocre: about 70% of units end within 2 studs of their slot, and the rest stop up to about 17 studs short where the crowd blocks them (D38 give-up). Better slot assignment (e.g. Hungarian matching, or reserving the approach lane) is a possible follow-up.

### Task 10 — Combat core

- `src/server/Sim/Combat/`:
  - `Combat.luau`: per-def collision and weapon profiles, terrain height, damage queue, `explode` with AoE falloff and friendly fire, projectile pool (u16 IDs, cap 2,000), wrecks, per-tick events, hash.
  - `ContactGrid.luau`: 64-stud buckets, team-filtered queries.
  - `Ballistics.luau`: low-arc launch pitch, exact step, segment vs cylinder, distance to cylinder, falloff.
- Systems:
  - `Targeting`: per weapon, staggered, sticky, priority scoring, fire states.
  - `Weapons`: turret yaw/pitch rates, tolerance, ballistic pitch, reload, spread from `sim.rng`, hitscan resolution, projectile spawn.
  - `Projectiles`: exact flight, swept collision against enemy cylinders and terrain, impact explosions, ttl.
  - `Damage`: queued damage by armor class, lastAttacker, deaths with severity, wrecks, DEATH events, order cleanup.
- `World` has per-weapon state (yaw, pitch, reload, target) and lastAttacker, all hashed. `Sim/Spawn.luau` spawns from defs. Scenario `duel_test`. `Sim.hash` includes combat.
- `.lune/debug_duel.luau`: `lune run debug_duel [seeds]` prints the duel outcome, shots, hits, kills and cost.
- Specs:
  - `Ballistics.spec`: launch pitch lands on target; reach; exact step; segment/cylinder cases including no tunneling; distance; falloff.
  - `Combat.spec`:
    - 10 Lancers vs 10 Ravagers until one side is gone, deterministic across runs and replay;
    - a slow turret (30°/s) first fires ≥60 ticks after a fast one (180°/s);
    - exact AoE falloff for 5 units at known distances, and friendly fire off spares allies;
    - a shell blast damages 3 tanks with the exact falloff from the impact point;
    - hitscan damage lands the same tick;
    - a 3,000 stud/s rail doesn't tunnel, and an ally in the line of fire is untouched;
    - wreck vs. obliteration by overkill; armor classes;
    - Hold Fire stays silent; Return Fire shoots back only after being attacked.
  - Mutation checks: letting projectiles hit allies, ignoring aim tolerance, and dropping the swept test were each caught.
- `Sim.spec`: "20 units after 1,000 ticks" became "both runs end with the same survivors", since the skirmish tanks now fight. The determinism check is stricter, not weaker.
- Tests: **17 specs, 129 passed, 0 failed**.
- Duel results (`lune run debug_duel 10`): Chaos wins 10 of 10 seeds with 5 Ravagers left after 221–244 ticks (about 15 s). 96–97% of shells hit, 15 kills and 15 wrecks per fight, about 0.024 ms per tick for 20 units. Placeholder stats; see D50.
- Decisions: D43–D50.

### Rules review

Checked every file under `src/` against CLAUDE.md and the skill:

- `--!strict` everywhere. ✅
- Requires: only `@shared/...` across roots and relative paths within a root. ✅
- No Roblox globals, Instances, `Random`, `math.random`, `os.clock`/`tick`/`time` in sim code (clocks only via `Util/Profiler`). ✅
- No `pairs()`-order dependence: every loop over a hash-keyed table only builds a set or copy, or sorts its keys first. ✅
- Replicated fields are written only through World setters (dirty bits); turret aim sets STATE dirty explicitly. ✅
- No print spam in sim code. ✅

Fixes made during the review and while building the tasks:

1. **Hot-loop allocations removed:**
   - Targeting created a closure per weapon per tick; it's now a module-level function.
   - `Nav.tree` built a string key per call from Movement; the key is now precomputed per profile.
2. **Queue bugs fixed:** two FIFO queues used `table.insert` / `#` on tables with nil head slots: World's free-ID queue (caught in review before tests) and Nav's job queue (caught by the wall-map march). Both now use explicit head and tail indices.
3. **Unused require** (`World` in Scenarios) removed. Stale guide reference (line of fire is now 10.8) fixed. `Route.findMany` edge case simplified.
4. **Logged, not fixed:** D51 (libm trigonometry across platforms).

Remaining allocations per event (FIRE, IMPACT and DEATH event tables; command-time tables in Nav) are per discrete event, not per unit per tick.

### Round 3 — answers, pathing fixes, duel reports

- The answers were applied:
  - D21 is confirmed; guide 5.5 now requires chokepoints ≥ 3 cells and 6.2 prefers odd footprints.
  - Work-unit budgets are approved.
  - Same-platform re-simulation is accepted; guide 17.1 separates player-facing stream replays from dev-only command re-simulation.
  - Test audit: no hard-coded simulation hashes.
- **Fix (a), direct-path shortcut (D52):** each unit's line to its slot is checked once (same leaf is exact and free, otherwise sampled). Units with a clear line steer directly, and a field is built only for the rest, or not at all. All 9 movement maps still arrive. Open maps build 0 fields.
- **Duel reports (D54):** `lune run report_duels [seeds]`. At equal cost (13 Lancers vs 15 Ravagers): close range, Chaos wins 5/5 (10 Ravagers left, 13 s); long range with Lancer kiting, Order wins 3/5 (2 Lancers left, 89–125 s) and Chaos wins 2/5 (about 34 s). Report only; no rebalance.
- **Fix (b), bucket queue (D53):** flow field integration uses Dial buckets. The output is byte-identical to the heap version, about 2.8× faster overall and 3.9× on integration. The pathing budget was recalibrated from 12,000 to 36,000 units per tick (≈ 8 ms).

### M3 — Economy and construction ✅ (headless)

- **M3.7 — scripted T1 build order (D64):**
  - Scenario `standard_start`; `Tests/Support/BuildOrder.luau` driver; `BuildOrder.spec`: both factions build 2 extractors, 2 generators and a plant, then get 3 tanks; no step fails, stored never goes negative; deterministic across two runs and the replay.
  - `lune run report_buildorder` prints the timeline: plant at about 43 s, three tanks by 90–107 s, then power-bound.
  - Tests: **21 specs, 151 passed**.
- **M3 rules review:**
  - Every new file is `--!strict` and uses allowed require forms. There are no Roblox globals, clocks or `math.random`, and no prints in sim code.
  - Every loop in the new modules runs over an array.
  - Replicated fields are written only via setters (the new `buildProgress` included).
  - The intentional side-effect require `_Placement` in Sim registers its Lifecycle hook; hook order is fixed by require order.
  - Allocations: `Build.step` creates one closure per tick, and `approach` allocates only when sending an idle builder off. Nothing is allocated per unit per tick.
  - **No fixes needed.**

- **M3.4–M3.6 — construction, factories, reclaim (D61–D63):**
  - `Sim/Build.luau` and `Sim/BuildState.luau`: BUILD (approach, placement check, frame, assist), per-tick progress × effective ratio with the allowance cap, health growth, completion, demand reporting; factory queues, production and the exit roll-out; REPAIR as assist; RECLAIM; removal hook.
  - Construction system, commands BUILD / REPAIR / RECLAIM; MOVE and STOP cancel build work. `Combat.removeWreck`; build events.
  - `Build.spec`: the CV builds a generator in exactly 60 ticks, which then produces; assisting is faster; a starved team builds more than 2× slower and never overspends; a missing deposit fails with a reason; a factory queue produces in order (Lancer at tick 675) and units roll out; assisting a factory more than halves production time; reclaim returns exactly the wreck's supply; a frame destroyed mid-build frees footprint and builders; determinism.
  - One test was wrong first: its team had no power income, so production correctly stalled at 2/3 for lack of power. The test now funds the economy.
  - Tests: **20 specs, 149 passed**.
- **M3.3 — placement and passability (D59, D60):**
  - `Passability`: occupancy layer, capped clearance, exact `updateRect`, `setOccupied` / `clearOccupied`.
  - `Sim/Placement.luau`: snap, check, occupy, release (as a Lifecycle hook). `Nav.terrainChanged`.
  - `Spawn.unit` occupies the footprints of structures it spawns.
  - `Placement.spec`: snapping; bounds, terrain, deposit, occupancy and unit checks; clearance equals brute force after placing 3 plants; destroying them restores every layer byte for byte; routes avoid new structures.
  - Tests: **19 specs, 140 passed**.
- **M3.2 — team economy (D57, D58):** `Sim/Economy.luau`: accounts, producer list, settlement every 5th tick, stall ratio, two-pass effective ratio, window allowance, storage cap and waste, hash. `Sim/Lifecycle.luau`. `World.buildProgress` with a BUILD dirty bit. `Economy.spec`: settlement math, effective ratio, starting accounts, income from the CV, extractor (deposit value) and generator, storage bonus, producer death, hash. Tests: **18 specs, 136 passed**.
- **M3.1 — defs and map (D55, D56):** economy def fields and validation; Command Vehicle, worker, extractor, generator and vehicle plant per faction; supply deposit and start layers; `start:<n>` map. The Defs index test now checks sorted order against the registry instead of hard-coded indices. Tests: **17 specs, 130 passed**.

### Round 8 — answers implemented ✅

- D106 pathfinding as physics (a known minor info leak). M8 item 2: blast weapons gain little from tracking.
- D107 domain-only radar contacts; D108 jammer upkeep; D109 unit generations and ghost pins.
- Tests: **34 specs, 253 passed**. Counter check 457 of 568, 192 findings.

### Round 7 — item 6: fire-control (tracking) radar ✅

- `track` sensor map. Radar contacts inside it are TRACKED: small wobble (Order 4–6, Chaos 10–12), real icon plus a TRACKED flag on the wire (`PROTOCOL_VERSION` 5), and bombers lead them. Jamming hides from it; power stalls shrink it (D104).
- +10% radar-SAM lock range against tracked targets (D105).
- New T2 defs: Tribunal and Arbiter (Order), Seeker Spire and Stalker (Chaos), in the Advanced Ground Worker and Advanced Vehicle Plant build options.
- `Tracking.spec` (7 tests): howitzer 4/15 → 11/15 direct hits; bomber on a moving tank 0/9 → 6/10. Balance section "Fire-control radar" (artillery duels on radar).
- Tests: **33 specs, 245 passed**.

### Round 7 — item 5: rearm airfields in balance fights ✅

- Aircraft groups get a durable Advanced Airfield behind their start and a full account; they rearm as in a match (D103).
- Air rows re-run: no "ran out of ammo" findings left. Counter check 456 of 568 pairs hold, 193 findings (50 mechanic, 143 numbers); band 34 of 38.

### Round 7 — item 3: homing-projectile corrections ✅

- New unreliable `Projectiles` channel: about 3 Hz corrections for homing projectiles in the player's view, plus one when a projectile comes into view. The client blends them in over 5 ticks (D102).
- Max visible drift: torpedoes 631 → 30 studs, AAMs 517 → 67, radar SAMs 171 → 59.
- Cost: about 45 B/s per homing projectile in view.
- Tests: **32 specs, 238 passed**.

### Round 7 — item 2b: server-truth audit ✅

- Fixed (D101): radar contacts are judged by their believed position in the targeting search. The AI plans placement with its team's knowledge, never reads a radar blip's type, and keeps dead ghosts as targets and threats.
- New `Knowledge.spec` (4 tests); each fails when its fix is undone.
- Open: pathfinding on true passability, and radar contacts' true categories in weapon filters.
- Tests: **32 specs, 236 passed**.

### Round 7 — item 2a: ghosts of dead structures, ATTACK_GROUND ✅

- Targeting follows team knowledge: ghosts stay targets after their structure dies unseen, until the spot is seen again (D100).
- ATTACK_GROUND for bombers: runs on a spot until another order.
- `Air.spec`: dead ghost bombed then forgotten; attack-ground on an empty spot. The ghost test fails without the dead-ghost search.

### Round 6 — item 5: combat events on the wire ✅

- New records FIRE, SPAWN_PROJ, IMPACT, DECOYED and LOST_LOCK (`PROTOCOL_VERSION` 3), sent only for what the player's ally team may know and batched per tick (D99).
- The headless client steps its projectiles. `MatchExport` v2 rebuilds the player view's projectiles and explosions from the wire, and the viewer draws `fire` tracers.
- Unguided projectiles match the server exactly. Homing missiles drift on radar contacts (up to about 600 studs in one export) until their IMPACT.
- Stress test, per player: Events 0.06–0.19 → 0.52–1.60 KB/s for 200–800 units. Tactical, State and Strategic are unchanged. The worst total is 20.7 KB/s (budget 35).
- Tests: **31 specs, 230 passed**.

### Round 6 — item 4: same-role band ✅

- Same-role pairs need mutual damage and an equal-cost trade within 0.5–2.0. They are listed in their own table in `BALANCE.md` (D98).
- Destroying nothing no longer holds a cell (0 ÷ 0 was ∞).
- Bomber balance fights now get a durable long-range radar at the map edge. The T1 tower died in close starts (D96, revised).
- Counter check: 452 of 568 pairs hold, 201 findings (71 mechanic, 130 numbers); band 32 of 38 fights inside.
- Tests: **31 specs, 227 passed**.

### Round 6 — item 3: destroyer SAM, missile guidance, matrix edits ✅

- Crusader and Corsair carry a radar-guided naval SAM (380 / 360 studs) (D97).
- While testing it: SAMs never hit a circling jet (pure pursuit, contact fuse only). Homing now leads the target, and missiles have a proximity fuse within their blast radius. Land SAMs and the naval SAM now down circling jets; the Hornet IR SAM still misses Falcons (M8 numbers).
- Guide 12.4: tanks and attack helicopters → helicopters are "—". `BALANCE.md` has an "M8 balance items" section, with IR SAM vs helicopters first.
- Counter check: 446 of 568 pairs hold, 223 findings (57 mechanic, 166 numbers).
- Tests: **31 specs, 227 passed**.

### Round 6 — item 2: bombs on radar contacts and ghosts ✅

- Bombs have `canTargetRadar`: radar contacts at the wobbled position, structure ghosts at their last known position; sight unchanged (D96).
- `Air.spec`: radar contact (5 drops, 6.3 studs from the blip, 23.8 from the tank) and ghost plant (both ghost drops damage it). Both fail without the flag.
- Balance fights give bomber groups their T1 radar tower. Sieges: Absolution 100%, Phantom 55%, Behemoth 92%, Plague 100% (were 37 / 0 / 4 / 85%).
- Tests: **31 specs, 225 passed**.

### Round 6 — item 1: shared aim point ✅

- `Combat.aimPoint` / `Combat.baseAt` are used by aiming, hit checks, homing, EW, bombs and explosions (D95).
- `Naval.spec`: hull aim point; a tank hits a stationary ship 19 / 19; an MLRS fires at ships and hits 7 / 10. The old aim fails both.
- Counter check: 425 of 568 pairs hold, 248 findings (84 mechanic, 164 numbers); no ship "never hit" findings left.
- Tests: **31 specs, 223 passed**.

### Round 5 — task 28: counter check ✅ (report only)

- `lune run balance` now also runs sieges (`Scenes.siege`) and coastal-battery fights. It checks every matrix cell of guide 12.4 (parsed from the guide) for every unit of the role on both sides, and diagnoses each shortfall from per-fight records (D94).
- **Result:** 412 of 568 pairs hold; 273 findings: 157 mechanic, 116 numbers. Details in `docs/BALANCE.md`.
- **Mechanic:**
  - ballistic fire at ships aims at the sea floor (tanks, artillery and coastal batteries never or rarely hit ships; MLRS never fire);
  - bombers can't line up runs (sight ≈ 200 < release ≈ 400);
  - destroyers have no SAM;
  - tanks and attack helicopters can't hit helicopters at all (the matrix says weak);
  - fighters and attack helicopters run dry without pads (a property of the report).
- **Numbers:**
  - same-role mirrors can't meet ●●● or ●● for both sides (an artifact of checking);
  - IR SAMs lose to helicopters (Halo vs Wasp 0.5–0.6);
  - destroyers lose to subs (0.34–0.52).
- Every fight can be watched: `lune run export matchup:<order>:<chaos>[:close|long]` or `siege:<unit>`.

### Round 5 — task 27: match viewer ✅

- `tools/viewer/index.html`: open a `lune run export` file (double-click the page, pick the file).
  - Draws terrain and water, units by category in team colours, projectiles and events, radar and sonar blips, ghosts, fog, and a minimap.
  - Play, pause, speed, scrub, zoom and pan; click a unit to see its state (D93).
- Checked in the browser pane: the AI match in spectator and player-1 views, and the Seraph-vs-Harpy radar matchup in player view (blips in the fog).

### Round 5 — task 26: match export ✅

- `lune run export` (D93): the spectator view, or one player's fog-filtered view rebuilt from real NetOut packets. Shared `Scenes` (AI match, balance matchups, Sim scenarios); `lune run balance` now uses `Scenes.matchup` (identical results).
- `Export.spec` (5 tests): JSON, base64, spectator data matches the sim, player view only shows what the client received, determinism.
- Tests: **31 specs, 220 passed**.

### Round 5 — task 25: wind, converters, extractor upgrades ✅

- Wind (seeded, stateless, every 30 s), wind turbines, toggleable supply converters (power above half storage), extractor upgrade replacement (D92). 4 new defs, added to the T1 economy build lists.
- `Economy.spec` (3 new tests): wind range, period and seeding, and turbine income; a converter burns exactly down to the reserve (500 power → 7.14 supply) and does nothing when switched off; an upgrade removes the T1 when it starts, others' or same-tier extractors block, and the result earns 1.75 × the deposit value.
- Mutations caught: toggle ignored, no reserve, upgrade keeps the T1.
- Tests: **30 specs, 215 passed**.

### Round 5 — task 24: proper bombing ✅

- BOMB weapons with a computed lead point, bomb runs with egress and go-around, and a bomber altitude of 130; rearming as before (D91).
- `Air.spec` (5 new tests): 4 / 4 bombs on parked targets; a moving column hit (1 / 2, and 0 / 2 without prediction); egress; return → rearm → bomb again; determinism. 3 mutations caught.
- Balance report re-run (all rows, `docs/BALANCE.md`). Bomber trades fell to 1.9–2.7, still with no wins: without spotters bombers can't see 400 studs ahead to line up a run (see D91).
- Tests: **30 specs, 212 passed**.

### Task 23 — Skirmish AI ✅

- `Sim/AI/Skirmish.luau`: a deterministic AI that plays through commands (D90). It runs a build order, expands to free deposits, builds an army and attacks in growing waves. New map `skirmish:<cells>`.
- `Skirmish.spec`:
  - Order AI vs Chaos AI on `skirmish:192`, Command Ends: Chaos wins at **8.0 min** (7,189 ticks), **peak tick 10.3 ms**; both sides attacked (1 and 3 waves) and expanded (9 and 8 extractors, beyond the 4 home deposits); 0 rejected commands;
  - a second run is identical (hash, length, winner), and the replay without the AI ends identically.
- Seeds 2–4: Chaos wins at 6.0, 7.8 and 6.3 min; peak ticks 8.7–9.3 ms; at most 60 units.
- **Rules review** for tasks 18–23: strict, require forms, no globals, clocks or random in sim code; every new loop over a dictionary sorts first or only clears; the Roblox build check passes (245 scripts, 701 requires).
- Tests: **30 specs, 207 passed**.

### Task 22 — Balance report ✅

- `lune run balance [seeds] [filter]` writes `docs/BALANCE.md` (D89): 1,064 battles (19 × 19 units, 2 starts, 2 seeds) in 190 s. Report only; no stats changed.
- **What the placeholder stats show** (value trade, geometric mean; wins / fights):
  - **Ships dominate:** cruisers 18–19×, carriers 11–18×, destroyers 3–5×, corvettes 5–11×. Only ships, bombers, subs and artillery can hurt them, and their health is high for their value.
  - **Bombers never win** (0 / 56 each) but trade 3.6–7.9×: they kill some units and can't be shot back by ground units without AA, then run out of bombs.
  - **Attack helicopters are strong** (Guardian 6.45, Wasp 7.51): only SAMs, flak and fighters can hit them.
  - **Ground units trade at about 0.4–1.1.** Juggernaut and Jackal are the best Chaos ground units (≈1.0); Seraph and Gorgon the worst, because radar SAMs only hit aircraft and lose to anything on the ground.
  - **MLRS** (Judgement, Hydra) and **ASW helicopters** (Tidewatch, Leech) never win: MLRS lose at close range; ASW helicopters only hit ships and submarines.
  - **Fighters:** Harpy 1.19 and Manticore 1.05 beat Falcon 0.82 and Archon 1.76 on wins (17 and 19 vs 8 and 4 of 40).
- Tests unchanged: **29 specs, 205 passed**.

### Task 21 — Full placeholder roster and tech tree ✅

- 79 new unit and structure defs (115 total: 57 Order, 58 Chaos) and 16 new weapons, generated from role templates (D88).
- Build options rewired per guide 9.1–9.2.
- Defs validation now allows carriers to have rearm pads.
- New `TechTree.spec`:
  - roster reachability for both factions; tech gating; move classes per role; domain and placement rules; every weapon can damage something it targets;
  - in-sim chains: shipyard → Tidewright → tidal, and airfield → Skywright → solar.
- Tests: **29 specs, 205 passed**.

### Task 20 — Match rules ✅

- **Teams:** `allyTeam` per player and `w.ally` per unit. Sensors, targeting, the contact grid, projectiles and friendly fire use ally teams; economy stays per team, with overflow shared to allies (D87).
- **New modules:** `Sim/Match.luau`, `Sim/MatchState.luau`, the `Sim.Match` system (after Construction), `Lifecycle.addedHooks`, unit-cap checks in Build, a `match_test` scenario, and replay header format 2 (ally teams plus match options).
- **`Match.spec`** (10 tests):
  - each win condition in both modes: FFA Command Ends (3 players), FFA Annihilation, Team Command Ends (2v2), Team Annihilation;
  - a draw;
  - allies share sight and never target each other (FFA shares nothing);
  - overflow: exactly 900 power goes to the ally in TEAM and is wasted in FFA;
  - unit cap: construction fails, the factory item waits, then rolls out when there is room;
  - config validation and default caps (300 in 1v1, 150 in 8-player FFA);
  - a fought-out 2v2 ends at 29.3 s and replays exactly.
- Mutations caught: no overflow sharing, no self-destruct, cap ignored, win conditions swapped, allies targetable (both redundant ally checks broken).
- Updated tests: the replay round-trip now includes ally teams and match options; the system-order test includes `Sim.Match`.
- Tests: **28 specs, 200 passed**.

### Task 19 — Local quadtree invalidation ✅

- `Quadtree.update` re-decides only the nodes touching the flipped cells, then patches leaves, IDs, neighbors and components. `Nav.terrainChanged` calls it for every tree (rectangle padded by the clearance cap) and restarts stale route searches (D86).
- **Tests:**
  - 40 random placements and removals on `gen:3:128`; 230 tree comparisons against fresh builds (including TRACKED need 2);
  - 4 mutations caught;
  - `Placement.spec`'s tree-identity check replaced by a behavior check.
- **Stress test** (800 units, now also placing 14 structures mid-battle; the harness reports it):
  - worst tick with a placement: 42–43 → 24–27 ms (the ordinary tick peak); the placement itself is ≤ 5.7 ms;
  - Movement peak: 31–35 → 14 ms.
- Tests: **27 specs, 190 passed**.

### Task 18 — Sensors performance ✅ (branch `m-sim-polish`)

- **Profile:** stamping is about 95% of Sensors time (12–23 ms per sensor tick at 800 units); visibility 0.2–0.4 ms, lists 0.3–0.7 ms, ghosts about 0 (D85).
- **Fix:** one-cell circle shifts, row-span circles, a full-stamp budget of 200,000 cells per sensor tick.
- **Sensors average / peak ms, before → after:**

  | units | before | after |
  |---|---|---|
  | 200 | 1.46 / 6.10 | 0.18 / 1.39 |
  | 400 | 2.39 / 12.42 | 0.31 / 3.48 |
  | 600 | 3.42 / 14.18 | 0.40 / 2.06 |
  | 800 | 4.16 / 21.56 | 0.54 / 2.14 |

  Target ≤ 5 ms met. Average tick at 800 units: about 12.1 → 9.2 ms.
- **Tests:**
  - the existing full-recount test covers shifts;
  - new: a 300-radar mass spawn is stamped in ids order within budget and catches up after 18 ticks;
  - mutations caught: off-by-one leading edge, off-by-one trailing z edge, budget ignored.
- Tests: **27 specs, 189 passed**.

### Round 4 — answers to the task 11–17 questions

- **1. COMMAND guidance (D80, revised):**
  - needs only a live launcher and the target VISIBLE to the launcher's team, checked every tick of the flight;
  - jamming, flares, chaff and DIRCM have no effect;
  - guide 11.5 table updated.
  - New `EW.spec` test: a COMMAND missile hits a jammed target carrying certain-success flares, chaff and DIRCM, which spend nothing. Killing the launcher or the spotter mid-flight raises `LOST_LOCK` and the sidestepping target is missed.
  - Mutations caught: jamming blocking the lock, no sight check, countermeasures rolling against COMMAND.
  - Tests: 27 specs, 183 passed.
- **2. Refill costs (D81, revised):**
  - new required `refillSupply` per flare or chaff charge;
  - the restock is spread over the rearm's rounds (`Air.rearmStep`, `EW.missingCharges` / `EW.addCharge`) and hashed in `AirState`.
  - New test: a Harpy missing 5 flares and 3 chaff pays exactly 19 supply more than one with full charges, rearms in the same 135 ticks, has part of its charges back at 4 s, and is full on take-off.
  - Mutations caught: free refill; restock only at the end.
  - Tests: 27 specs, 184 passed.
- **3. SAM target choice (D82, revised):**
  - Targeting gives guided missiles a lock preference (×1,000), re-searches every 6 ticks while holding a target, and switches only on a 1.25× score margin.
  - Bug fixed: jets spawned without orders now start at minimum speed; before, they hung motionless.
  - New tests:
    - **escort:** a jammer aircraft flying 25 studs behind fighter A. The Aegis fires 0 missiles at A and 8 at B, and is aimed elsewhere only 38 ticks while B is lockable (bound: 6 ticks per time B becomes lockable, 7 times). Once B is gone it tracks a jammed aircraft 221 of 300 ticks without firing. Without the escort it engages both (7 and 7).
    - **hysteresis:** radar wobble swaps which of two Wasps (500 and 505 studs) looks closer 10 times; the SAM never switches.
  - Mutations caught: no lock preference (102 wasted ticks), no re-search (258), no hysteresis (switches).
  - Tests: 27 specs, 186 passed.
- **4. Close submarine detection (D76, revised):**
  - `Sensors.CLOSE_SONAR = 40`: naval units and ASW helis (HELI with a SUB-capable weapon) make a submerged sub a SONAR contact.
  - New placeholders: Tidewatch and Leech ASW helicopters.
  - New `Naval.spec` test:
    - a sonar-less corvette at 30 studs sees a SONAR contact; at 55, nothing;
    - a sonar-less ASW heli at 35: SONAR; at 50: nothing;
    - an attack heli at 20 and a tank on the beach: nothing;
    - the ASW heli then drops torpedoes on it, and it is never VISIBLE.
  - Mutations caught: helis excluded, range 400, everyone detecting.
  - Tests: 27 specs, 187 passed.
- **5. Move-order spike (D83):**
  - **Profile:** see D83. Quadratic slot assignment was ~1.3 ms per 200-unit command, not the main cost. The big costs were the lazy quadtree build (10–17 ms), the coarse route and corridor (5–12 ms) and the per-unit line checks (2–6 ms).
  - **Fix:**
    - quadtrees and the formation spiral are built at load;
    - line checks, route and corridor move into a work-unit-sliced plan job (resumable `Route` search);
    - exact bucketed greedy assignment;
    - issuing shares the tick's pathing budget.
  - New `Movement.spec` test: the bucketed assignment equals the brute-force greedy on 60 random cases with ties. Mutations caught: early stop, no tie rule.
  - The stress harness now reports the worst Commands + Pathing tick.

    | units | worst move-order tick before → after (ms) | Commands peak before → after | max tick before → after |
    |---|---|---|---|
    | 200 | 60.4 → 11.4 | 49.8 → 0.8 | 61.5 → 13.8 |
    | 400 | 68.9 → 12.8 | 59.1 → 2.4 | 70.9 → 16.6 |
    | 600 | 80.6 → 12.7 | 70.2 → 3.3 | 85.1 → 26.4 |
    | 800 | 91.4 → 10.2 | 81.9 → 6.5 | 95.3 → 28.6 |

    Repeated 800-unit runs give worst move-order ticks of 8.7–11.6 ms. The remaining max-tick peaks are Sensors (14–22 ms) and Movement (10–13 ms).
  - Tests: 27 specs, 188 passed.
- **6. Offline Roblox build (D84, STUDIO_HANDOFF step 1):**
  - darklua 0.19.0 via Rokit; `.darklua.json` (`convert_require` with the Rojo sourcemap); `build.project.json`;
  - `lune run build` (sourcemap → darklua → `rojo build` → check) and `lune run check_build`.
  - The built place: 143 scripts compile; 482 requires all resolve to ModuleScripts.
  - The checker fails, as it should, on an unconverted place, a missing child, a Folder target and a syntax error (exit code 1).
  - Only the in-Studio run (serve `build.project.json`, confirm runtime requires) remains.

### Task 17 — Electronic warfare (M7) ✅

- `Sim/EW.luau`, `Sim/EWState.luau`:
  - lock checks for IR, RADAR (burn-through, stealth) and COMMAND;
  - midcourse every 5 ticks (`LOST_LOCK`) and the terminal countermeasure roll (`DECOYED`, a 60° veer);
  - flares, chaff and DIRCM (cooldown; power drain at the stall ratio); refill on rearm;
  - all rolls through `sim.rng`.
- Integration:
  - Weapons won't launch without a lock; Projectiles calls `EW.guide` before steering.
  - Combat has `pFlags` (hashed) and the `DECOYED` / `LOST_LOCK` events.
  - Build runs DIRCM upkeep; Spawn initializes countermeasures; Air refills them on rearm; `Sim.hash` covers `EWState`.
- Defs: Vigil/Thorn IR SAM sites, Aegis/Wyvern radar SAM sites, IR and radar SAMs, the `burnThrough` field, countermeasures on the four aircraft (D81, D82). Scenario `ew_test`.
- `EW.spec`:
  - **jammer vs radar SAM:** unjammed at 550 studs the Aegis launches and hits (2/2). Jammed at 550 and at 250 it never launches, though the Wasp is VISIBLE 300 of 300 ticks. Jammed at 150 (inside the 210 burn-through) it launches and hits (2/2).
  - **mid-flight jamming:** a jammer arriving after launch makes the missile raise `LOST_LOCK` and miss.
  - **DIRCM:** 25 of 40 single IR missiles decoyed. In salvos of 4 at most one per salvo is decoyed (14 of 80); 66 of 80 hit.
  - **DIRCM power:** with power it recharges within 4 s; with the team's power gone it never recharges, and 10 of 10 later missiles hit.
  - **charges:** 2 flares decoy 2 IR missiles and the third hits; chaff is untouched by IR and decoys the radar missile; refill restores both.
  - **lock rules:** IR locks a jammed target that radar can't; stealth (0.3) cuts radar lock range to 180; IR needs VISIBLE (a radar-only contact can't be locked); a COMMAND missile hits while its launcher lives and loses lock when the launcher dies.
  - **replays:** the `ew_test` scenario replays exactly.
  - Mutation checks, each caught: no jam lock check, no DIRCM cooldown, recharge ignoring power, no midcourse, flares never spent, COMMAND ignoring the launcher, no stealth, IR without visibility, Weapons ignoring the lock.
- `Air.spec` intercept: the Wasp's flares are set to 0 in the setup (D82); assertions unchanged.
- Tests: **27 specs, 182 passed**.
- **M7 rules review** (task 17):
  - strict, require forms, no globals, clocks or random: clean; all rolls go through `sim.rng`;
  - no `pairs()`-order dependence: EW loops run over `w.ids` and `sensors.teams` (arrays); `EWState.hash` walks the ascending id list;
  - no unused requires;
  - no allocation in `EW.guide`, `EW.canLock` or `EW.drainStep` beyond the event tables every system emits;
  - **one fix, a performance regression found by re-running the stress test:** Movement sized its spatial-hash search from the largest radius *in the roster*. Task 16's footprint-3 destroyers widened every unit's search from 3×3 to 5×5 buckets, and Movement at 800 units went from 4.3 to 7.0 ms. It now uses the largest radius among the units present that tick. The results are bit-identical (same survivors and kills); Movement is back to 4.2 ms.

### Task 16 — Naval (M6) ✅

- Map `sea:<n>` (land on the west quarter, deep water elsewhere).
- Combat: ships' hulls hang from the water surface (draft 3); submerged subs 10 studs down; `Combat.surfaceHeight` and `Combat.waterDepth`.
- Spawn sets `SUBMERGED` on every SUB-class unit.
- Weapons: torpedoes launch level just under the surface. Projectiles: torpedoes are clamped to the water column and removed at the shore. Targeting: torpedoes may shoot SONAR contacts.
- Defs: Sentry/Barracuda corvettes, Silence/Lamprey subs, Crusader/Corsair destroyers; naval guns, torpedoes, ASW torpedoes; guidance `ACOUSTIC` (D76–D78).
- `Naval.spec`:
  - a corvette, a destroyer and a sub ordered 200 studs inland stop at the shore and never enter water shallower than their class's `minDepth`;
  - a sub 100 studs from an enemy corvette (sight 220, no sonar) stays HIDDEN with no known position, while a surface ship at the same range is VISIBLE; a destroyer's sonar then makes it a SONAR contact, never VISIBLE;
  - a tank on the beach and a corvette's gun never target a known sub; only torpedoes shoot at it;
  - a torpedo fired at a tank on land stays under the surface and is removed at the shore with no damage;
  - a Crusader sinks a Lamprey 200 studs away in 8.5 s with ASW torpedoes, keeping 1960 / 2600 HP, and never fires its gun at it;
  - determinism.
  - Mutation checks: no SUBMERGED on spawn, no shoreline removal, no SONAR targeting and no water-column clamp are each caught.
- Tests: **26 specs, 175 passed**.
- **M6 rules review** (tasks 15–16):
  - strict, require forms, no globals, clocks or random: clean;
  - no `pairs()`-order dependence: the new loops run over `w.ids` and def arrays; `AirState.hash` walks the ascending id list;
  - no unused requires;
  - one fix: rearming built an empty cost table per unit per tick when a def had no `ammoCost`; it now uses a frozen constant;
  - accepted: `Air.nearestPad` scans all units (only when an aircraft runs dry or its pad dies), and `Air.rearmStep` walks the unit list twice per Construction tick (O(n), no allocation).

### Task 15 — Air (M6) ✅

- `Sim/Air.luau`, `Sim/AirState.luau`:
  - jet steering (min speed, turn rate, loiter circling, chase, map edge);
  - altitude bands; ammo use; return to the nearest pad, landing, rearming through the economy, take-off and resume.
- Integration:
  - Movement has a jet branch, updates altitudes, and skips jets in overlap resolution.
  - Projectiles do homing steering and test collisions in each target's frame.
  - Targeting lets jets acquire outside their arc; Weapons spend ammo; Build runs rearming as a consumer; Spawn initializes aircraft.
  - Nav profiles have `jet` and `minSpeed`.
- Defs: Falcon and Harpy fighters, Guardian and Wasp helicopters, Aerie and Roost pads, missiles and rockets (D75).
- `Air.spec`:
  - a Falcon intercepts an incoming Wasp (killed at 22.9 s with 3 missiles, 3 hits), never drops below minimum speed, then circles its point (more than 2π of turning in 30 s);
  - an empty Falcon goes fly → return → rearm (landed on the pad, LANDED) → fly with full ammo and back out;
  - rearm takes 120 ticks at full economy versus more than 3× on a power stall;
  - a helicopter hovers at 35;
  - determinism.
  - Mutation checks: removing the min-speed clamp, ignoring the stall in rearm, and never spending ammo each fail their test.
- Tests: **25 specs, 169 passed**.

### Task 14 — Stress test and bandwidth report ✅

- `Sim.enableTiming` (D72) and `.lune/stress.luau`. `lune run stress 900 200 400 600 800` writes `debug_out/stress.txt`.
- Results: see **Stress test** under Benchmarks below.
- Tests unchanged: **24 specs, 164 passed**.

### Task 13 — Interest management and NetOut (headless) ✅

- `Schema`: Events records ENTER/LEAVE/DEATH, `PROTOCOL_VERSION` 2 (D70).
- `Sim/NetOut.luau`, `Sim/NetState.luau`, NetOut system, CAMERA command (D71).
- `Tests/Support/Client.luau`: decodes one player's packets into a world view.
- `NetOut.spec`:
  - 1,000-tick battle with radars, a jammer and structures: no client ever receives a unit its team can't know; tactical and state records only for seen units; radar blips only at their wobbled cell with icon 0; every message ≤ 900 bytes (largest 204); at the end each client's view equals server knowledge (tactical positions within 1/32 stud, health exact).
  - Camera hysteresis (+2 enter, +5 leave).
  - 400 movers split into ≥ 4 messages, each mover sent once.
  - Mutations caught: hidden units leaking into strategic records; radar contacts at true positions.
- Movement.spec's "idle units cost nothing" now checks packets (no tactical or state messages from idle units) instead of dirty bits, which NetOut clears every tick. This makes it stronger, not weaker.
- Tests: **24 specs, 164 passed**.

### Task 12 — Wobble, jamming, stealth (M4) ✅

- `Sensors`:
  - `radarDetects` (jam map of the target's team; stealth against each observer radar within range × signature);
  - per-team radar emitter list and best radar error;
  - `wobble` (stateless, smooth, per observer) and `knownPosition`.
- Targeting accepts only known targets (radar contacts and ghosts for `canTargetRadar`). Weapons aim at known positions; hitscan is judged against the truth.
- Defs: `sensors.radarError`; Veil and Shroud jammers; Verdict and Hellmouth artillery with radar-targetable guns. Tank sight now covers weapon range (D68).
- `Fog.spec`:
  - wobble is bounded, deterministic, smooth and per observer;
  - a jammed tank is off enemy radar but still visible to sight;
  - a stealth unit (signature 0.3) shows on radar exactly within 210 studs of a 700-stud radar, checked every sensor tick along a walk through all three bands;
  - a unit with 40-stud sight never fires at an in-range unseen enemy, and fires once a friendly spotter sees it;
  - radar-targeted artillery hits directly 20% of the time versus 87% spotted.
  - Mutation checks: removing the jam or stealth check fails the matching test.
- Three earlier tests read hard-coded sight and index values; they now read them from the defs.
- Tests: **23 specs, 160 passed**.
- **M4 rules review:**
  - strict, require forms, no globals, clocks or random: clean;
  - the only dictionary loop (visibility hash) sorts first;
  - no unused requires;
  - the sensor tick allocates nothing per unit (radar lists cleared and refilled, stateless wobble, cached radii).
  - No fixes needed.

### Task 11 — Sensors (M4)

- `Sim/Sensors.luau` + `Sim/SensorsState.luau`:
  - per-team u16 maps (los, airLos, radar, sonar, jam); cached circle offsets;
  - stamp and unstamp on sensor-cell change, with no allocation (radii cached per def);
  - visibility levels with structure ghosts; `Sensors.level(sim, team, id)`;
  - hash, and a Lifecycle unstamp hook.
- World state bits SUBMERGED and LANDED. Placeholder mobile radars Oracle and Watcher (D66). Def sensors gained `airSight` and `jam`.
- `Sensors.spec`:
  - 30 units moving and dying for 240 ticks: the maps always equal a recount of the stamped circles, and stamps never trail positions by more than one cell; after everyone dies, every map is zero;
  - a Ravager walking past an observer: HIDDEN → VISIBLE → HIDDEN, exactly matching the sight circle on every sensor tick;
  - ghosts persist out of sight and after death, and disappear once the spot is seen;
  - radar contact beyond sight; unfinished units don't emit.
- Tests: **22 specs, 155 passed**.

## Benchmarks

Lune 0.11 on the dev PC, 256×256, median over 7 runs (best in the second figure), ms:

| map | passability (load) | quadtree | route | corridor cells | **flow field** | of which integration | work units | units/ms |
|---|---|---|---|---|---|---|---|---|
| open | 77 | 1.4 | 0.00 (1 leaf) | 65,536 | **80.2** / 78.3 | 70.1 | 131,071 | 1,634 |
| maze (zig-zag, 16-cell spacing) | 76 | 12.0 | 9.1 (707 leaves) | 43,141 | **31.5** / 31.3 | 24.7 | 86,281 | 2,742 |
| island (r = 110, hills + lakes) | 76 | 5.5 | 1.3 (32 leaves) | 10,236 | **9.9** / 9.8 | 8.3 | 20,471 | 2,076 |

**Against the 8 ms Pathing budget (guide 18.1): every one-shot field is over budget.**

- Open: 10× over. Maze: 4× over. Island: 1.2× over.
- With deterministic slicing at 12,000 units per tick (D33), the fields complete in 11, 8 and 2 ticks (0.73 s, 0.53 s, 0.13 s). Units steer straight toward the goal until then, which guide 6.4 allows.
- Integration (Dijkstra with a binary heap) is about 85% of the cost.
- The open map is the worst case: the whole map is one leaf, so the corridor is all 65,536 cells.

### Stress test, re-run after task 17

Same harness (`lune run stress`) on 2026-10-20 after the PC reset. This PC now runs slower than when task 14 was recorded: the task-14 commit itself measures **12.2 ms** average at 800 units here, against the 7.28 ms in the table below. Compare rows within one table only.

| units | avg | p95 | max | Sensors avg / peak | Movement avg / peak | Commands peak | total KB/s (player 1) |
|---|---|---|---|---|---|---|---|
| 200 | 3.15 | 5.88 | 52.4 | 1.48 / 16.3 | 0.70 / 4.3 | 42.8 | 5.63 |
| 400 | 5.94 | 11.13 | 61.4 | 2.38 / 9.5 | 1.79 / 6.8 | 48.8 | 12.41 |
| 600 | 8.72 | 15.15 | 74.6 | 3.21 / 13.2 | 2.87 / 8.1 | 63.9 | 18.07 |
| 800 | 12.08 | 20.41 | 94.8 | 4.19 / 17.0 | 4.22 / 11.6 | 82.0 | **21.53** |

- No system is over budget on average. The peak offenders are unchanged: Commands (the O(n²) slot assignment for a 400-unit order) and Sensors.
- At equal footing (task-14 commit vs now, same PC, alternating runs) the tick is unchanged once the Movement fix is in: 12.2 vs 12.1 ms.
- The battle differs slightly from task 14's (355 vs 335 survivors at 800) because task 15 changed projectile collision to the target's frame.

### Stress test (task 14)

Lune on the dev PC, 60 s of game time per size, two mixed armies attack-moving into each other on `gen:4:256`. Each player watches a 40×30-cell camera over the middle.

**Tick time (ms):**

| units | avg | p95 | max | alive at end | kills |
|---|---|---|---|---|---|
| 200 | 1.68 | 4.21 | 47.7 | 97 | 103 |
| 400 | 3.31 | 7.80 | 52.0 | 170 | 230 |
| 600 | 5.35 | 12.23 | 65.7 | 256 | 344 |
| 800 | 7.28 | 16.54 | 71.0 | 312 | 488 |

**Per system at 800 units, ms per tick, average / peak against the budget:**

| system | avg | peak | budget |
|---|---|---|---|
| Commands | 0.07 | **59.25** | 1 |
| Economy | 0.00 | 0.02 | 1 |
| Sensors | 2.43 | **15.99** | 5 |
| Targeting | 0.56 | 3.00 | 8 |
| Pathing | 0.44 | **8.44** | 8 |
| Movement | 2.59 | 9.30 | 10 |
| Weapons | 0.30 | 1.15 | 5 |
| Projectiles + Damage | 0.10 | 0.60 | 8 |
| Construction | 0.03 | 0.07 | 2 |
| NetOut | 0.75 | 3.87 (7.85 at 600) | 6 |

**Bandwidth per player (KB/s), worst player:**

| units | tactical (≤ 15) | strategic (≤ 10) | state + events (≤ 10) | total (≤ 35) |
|---|---|---|---|---|
| 200 | 1.91 | 1.65 | 2.03 | 5.59 |
| 400 | 4.32 | 3.00 | 4.51 | 11.83 |
| 600 | 6.89 | 4.42 | 4.77 | 16.08 |
| 800 | 9.12 | 5.66 | 6.59 | **21.37** |

**Verdict:**
- **On average, nothing breaks budget up to 800 units** (7.3 ms of 66.7 ms per tick).
- **The first system to break budget is Commands, on its peak:** 38–59 ms in the tick a 400-unit attack-move is issued, making the worst tick 71 ms at 800 units.
  - Cause: `Nav.issueMove` does greedy slot assignment, which is O(n²) (160,000 distance checks for 400 units), plus one sampled line check per unit.
- **Sensors is next:** its peak (6–16 ms against 5) comes from the first full stamp and from all-pairs visibility. Its average grows linearly (2.4 ms at 800), so it would reach 5 ms around 1,600 units.
- **Pathing** peaks right at its sliced budget (8.4 ms), as designed.
- **Bandwidth** stays under every target; the worst total is 21.4 KB/s at 800 units.

**Suggested fixes (not done, as instructed):**

1. **Commands spike:**
   - Assign slots in O(n log n): sort units and slots along the approach axis, then pair in order.
   - Do line-of-sight checks with a quadtree-leaf walk instead of 2-stud sampling.
   - Spread very large orders over a few ticks (a queue with a per-tick unit budget, deterministic).
2. **Sensors:**
   - Event-driven visibility (guide 11.3): recompute only units whose sensor cell changed, plus those under changed map cells.
   - Stagger the per-team passes across the two sensor ticks.
   - Stamp circles as row spans.
3. **Re-measure on a live Roblox server** with `--!native` before optimizing further. Desktop Lune numbers are not server numbers.

**After fix (a), direct-path shortcut.** `lune run bench` now also times whole move orders (issue + jobs to completion), median ms:

| map | 1 unit | fields | 50-unit block | fields |
|---|---|---|---|---|
| open | **0.02** | 0 | **0.35** | 0 |
| maze | 44.7 | 1 | 45.1 | 1 |
| island | 14.0 | 1 | 17.6 | 1 |

The open-map worst case (one 80 ms field) is gone. Without the same-leaf test, sampling 50 long lines took 8.4 ms. Maze and island still need their fields; the order cost there adds the leaf route (about 9 ms in the maze) to the field.

**After fix (b), bucket queue** (same maps, median / best ms):

| map | flow field (was) | of which integration (was) | units/ms (was) | move order, 1 unit | move order, 50 units |
|---|---|---|---|---|---|
| open | **28.3** / 27.9 (80.2) | 18.1 (70.1) | 4,633 (1,634) | 0.02 (no field) | 0.45 (no field) |
| maze | **18.1** / 17.9 (31.5) | 11.2 (24.7) | 4,780 (2,742) | 27.6 | 28.2 |
| island | **4.3** / 4.3 (9.9) | 2.7 (8.3) | 4,770 (2,076) | 8.0 | 11.4 |

Against 8 ms: the island field is now **within budget**. Open and maze are still over as one-shot jobs (3.5× and 2.3×), but sliced at 36,000 units per tick they finish in 4 and 3 ticks (0.27 s and 0.2 s). On open ground the shortcut means the field is rarely needed. The maze's move order also pays about 9 ms for the leaf-level route (`Route.findMany`), which isn't time-sliced yet. That's the next main-thread cost to watch.

Suggested fixes, in order of value per effort (as listed before fix (a); 1 and 2 are now done):

1. **No field when start and goal share an open leaf.** A leaf is a passable square, so the straight line inside it is always clear. This removes the open-map worst case entirely and helps every route's last leaf. *Cheap; will be used in task 9.*
2. **Bucket queue instead of a binary heap.** Integer costs 10/14 with Dial's algorithm make queue operations O(1). Expect about 2× on integration.
3. **Tighter corridor on open terrain.** Clip huge padding leaves to the route's bounding box plus a margin (D28 option).
4. **`--!native` on the path modules.** Roblox servers run Luau native codegen; numeric loops like these typically gain 1.5–3×. Must be measured on a live server.
5. **Actors (guide 6.4).** Move integration off the main thread so the main-thread budget only covers dispatch and apply. Results must be applied at a deterministic tick (D29).
6. **Cache hits.** All units in one order share a field, and repeated orders to the same goal hit the LRU, so real per-tick load is far below one field per order.
