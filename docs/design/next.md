# Next simulation work, ranked (for review)

Status: **a proposal for the user's review**, refreshed 2026-10-24 after S-158..S-166. Ranked by what it would do for the game soonest, weighed by cost. Size: S (an evening), M (a night), L (several). Done items are at the end.

## 1. The live server's budget, round 2 (S–M) — waits on B's watchdog run 2

- **Where it stands:** B's Studio run 1 (client request 65) and `lune run profile_match` found Damage (structure removals, eliminations), Pathing (idle-tick tree updates) and `nearestOpen`; all three fixed in S-164, and `--!native` is on Targeting, Movement and Sensors.
- **Still open:**
  - **Commands' spikes:** 3–5 ms single `Nav.issueMove` calls that don't reproduce outside a running match (likely garbage collection). Its average is 0.29 ms. Run 2 shows whether S-164's allocation cuts helped; if not, move order issuing into the Pathing job.
  - **NetOut:** 12–18 ms spikes with one spectator, who has every unit tactical. Look at the spectator path and strategic ticks first.
  - Actors only if those aren't enough.
- **Next step:** run 2 on the merge commit, same profile and seed, side by side with run 1.

## 2. Terrain-cut radar (M; client request 66, the user's reference 6)

- A shared pure function (`Shared/Sensors/RadarLos.cells(layers, x, z, emitterHeight, radius)`) that Sensors stamps per radar emitter, so B draws exactly the server's coverage, cut by terrain like BAR's.
- Agreed with B; it comes after the budget work. Radars that move (mobile radars) re-stamp on cell change, as now; the cells per emitter position can be cached.

## 3. Order still wins most AI matches (M–L, needs your decisions)

- faction_ai at the last run: Order 82% of same-level matches (target 40–60%). The next balance checkpoint now also writes `docs/FAIRNESS.md` (S-162) and picks up the new inputs since the last one: WALKER Commanders, factory facing, beams along the line, the AI's reach fixes, the advanced pads and SAM platforms.

## 4. Commander weapons (M, design under "Needs my review" in sim.md)

- A light main gun and a BAR-style D-gun: your call on the proposal's numbers, then build (a manual-fire command, power per shot, what it does to wrecks and allies).

## 5. The AI and the new T2 structures (S)

- The AI doesn't build the naval SAM platforms or the advanced rearm pads yet (S-166), nor face its airfields and shipyards (S-160).

## 6. The base grid (parked, S-161)

- Branch `s161-grid`: a block lattice keeps 2-cell lanes between any sizes but cost the AI's economy (fewer generators, less power at 8 minutes). Worth a second look only if mixed-size walling comes back; give-ups are down to 2 in 16 matches without it.

## 7. Remaining guide audit items (S each)

- non-square footprints (13);
- carriers building aircraft (5);
- a hover roster unit (4);
- optional: terrain-occluded line of sight (11.2; shares item 2's work), elevation sight bonus (5.5).

## 8. New units and systems not in the audit (each a design decision first)

Transports, cloaking, capture, self-destruct, resurrect, veterancy, morph.

## Not planned unless asked

- **4-stud cells:** the wire's u16 cell caps maps at 256 × 256 (1024 studs at 4 studs a cell). Flow fields would cost about 4×, and footprints, the guide and every map would change.
- **Homing corrections every 2 ticks for radar-only contacts** (client request 11a): measured in S-165, −5% drift for +63% homing bytes since blips moved to their unit's true cell.

---

## Done since the last list

- Own units off camera: OWN_STATUS (S-158, protocol 34).
- Commanders walk: WALKER, 40° (S-159). Factory facing and the AI's facing toward the enemy (S-160).
- The AI's give-ups: reach-checked deposits, units ordered while driving out of a factory (S-161; 59 → 2 in 16 matches).
- The fairness run as its own report (S-162).
- Beams burn the first enemy on their line (S-163).
- The live server's budget, round 1 (S-164).
- Naval SAM platforms and advanced rearm pads (S-166).
