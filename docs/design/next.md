# Next simulation work, ranked (for review)

Status: **a proposal for the user's review** (overnight 2026-10-22, after S-62..S-78). Ranked by what it would do for the game soonest, weighed by cost. Size: S (an evening), M (a night), L (several).

## 1. Order wins AI matches nine times in ten (M–L)

- **The gap:** `docs/FACTION_AI.md` has Order winning about 90% of same-level matches (target 40–60%). In the trade check, at equal value, every shared role is within 0.8–1.25 (S-62).
- **What rules things out** (S-78):
  - None of the following moved the share outside 86–93%: the faction AI styles (S-76); bigger or smaller Chaos waves; safe expansion; artillery ranges at their ±10% limits; T1 tank numbers all tilted ±10% toward Chaos; even Lancer-equal accuracy for the Ravager.
  - Kill tallies of 6 Normal matches: Lancers kill 39–52 Ravagers for every 9–22 the other way. Chaos loses 75 of 81 workers it builds; Order loses 3 of 20. Chaos gathers twice Order's power and still fields the smaller army.
- **Where units die** (the same 6 matches): Chaos loses 77 of its 95 dead workers in Order's half of the map (Order: 35 of 46), and half of its army dies at home (74 of 146), against 27 of Order's 94. Order wins as the attacker, and Chaos keeps expanding into Order's half.
- **The likely cause:** how fights happen in a match, not the numbers. Waves meet rallying or recalling defenders piecemeal (Order's "defend" case, 1.4–2.9), and Chaos's workers walk into Order's army and turrets.
- **Next steps:**
  - (a) a match-shaped trial in `lune run factions`: small waves against a rallied defender with turret and artillery support, to reproduce the gap outside the AI;
  - (b) give the AI value-based waves, and retreat when outnumbered, for both factions;
  - (c) keep Chaos workers out of contested deposits until an army escorts them.
  - Only then retune numbers, beyond ±10% if needed: your call.

## 2. Playable matches in Studio (L, mostly client)

M1's open items (map bake, tactical replication, interpolated rendering, overlays) are the client stream's. The sim side is ready.
- The sim should follow with what a live server needs: a per-tick budget watchdog in Roblox (the Lune timings are noisy and not Roblox's).
- It should also profile on Roblox's native code generation once the client runs matches.

## 3. Commands at 800 units (S, a decision)

Targeting is within budget (S-74). Commands peaks 1.8–2.2 ms (budget 1) only by changing behaviour. Pick one:
- (a) check attack-move holds for half the units each tick;
- (b) spread a big order's queue entries over 2–4 ticks.

Either is an evening's work, with a test that the hash difference is only the timing.

## 4. The two designed faction units: Phalanx and Wraith (M each)

Mechanism designs are under "Needs my review" in `docs/progress/sim.md`.
- **Phalanx (shield dome):** a new projectile and hitscan intercept test.
- **Wraith (decoy drones):** a `spoof` field and the strategic icon of untracked contacts.

Both need wire additions (a DOME state bit, the spoofed icon) that the client would draw.

## 5. Maps the AI can play: Normandy (S)

Normandy has no supply deposits, so 43% of its AI matches end undecided at 40 minutes (`FACTION_AI.md`). Either:
- add deposits to `Shared/Grid/Normandy` (behind each side's river, some in the bocage);
- or teach the AI a deposit-free economy (generators and converters only).

The first is cheaper, and better for players too.

## 6. Remaining guide audit items (S each)

From the 2026-10-22 audit, still open:
- flying sight bonus (item 10's third part);
- group speed matching (12);
- non-square footprints (13);
- BEAM damage over time (16);
- carriers building aircraft (5);
- a hover roster unit (4);
- a naval SAM platform and an advanced rearm pad (15);
- homing corrections more often than every 5 ticks for radar-only contacts (client request 11a).

Not in the audit and not built: transports, cloaking, capture, self-destruct, resurrect, veterancy, morph. Each is a design decision first.

## 7. AI completeness (M)

The AI never:
- builds nukes or the anti-nuke umbrella;
- builds Pinpointers, Barriers or the Citadel;
- uses naval and air at Normal.

Each makes AI matches look more like the game players will play, and they feed item 1's measurements.

## 8. Balance passes on what's measured but out of target (S–M)

- **Conditions not met:** the T1 fighters, the Herald at range, and the Locust (which loses to Lancers close and long).
- **Counter check:** 266 findings (87 mechanic, 179 numbers).

Worth a pass after item 1, since the AI's way of fighting decides what "balanced" has to mean.

## 9. Tooling that makes the above faster (S)

- `faction_ai` and `ailevels` take 5–20 minutes; matches are independent, so a Lune process per map in parallel would cut that to the longest map.
- Deterministic work counters (sensor lookups, path work units) next to the noisy timings in `stress` / `profile_normandy`. S-74 had to count calls by hand to show its effect.
