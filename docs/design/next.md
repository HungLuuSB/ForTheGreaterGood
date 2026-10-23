# Next simulation work, ranked (for review)

Status: **a proposal for the user's review**, refreshed 2026-10-23 after S-102..S-140. Ranked by what it would do for the game soonest, weighed by cost. Size: S (an evening), M (a night), L (several). Done items from the previous list are at the end.

## 1. Measure the real server (S, then M) — waits on B wiring the watchdog

- **Now possible:** the per-tick watchdog (S-140) is built. Once B calls `Watchdog.afterStep` in `src/roblox/Main.server.luau`, a Studio match logs ticks over guide 18.1's budget with the worst systems.
- **Then, from the numbers:**
  - fix the systems the live server shows over budget. Commands still peaks at 1.78 ms in the Lune stress test (budget 1; S-100, S-107);
  - try Roblox's native code generation (`--!native`) on the hot systems (Targeting, Movement, Sensors), measured the same way;
  - move work to Actors only if those aren't enough.
- **Why first:** every other item assumes the sim fits a live server at 800 units. Nothing has measured that on Roblox yet.

## 2. Order still wins most AI matches (M–L, needs your decisions)

- **Where it stands:** faction_ai at the last run: Order 82% of same-level matches (target 40–60%). Every shared role trades within 0.8–1.25 at equal value (S-62). The pass in S-112 put 12 of 12 roles in band.
- **What's left:** the retunes beyond ±10% (S-91) and the proposals under "Needs my review" in `sim.md` (fighters, the Herald, the T2 tank condition).
- **Next step:** run the balance checkpoint when you ask for it. It now has new inputs since the last run: footprint sizes, the AI's outweigh rule, T2 defences, nukes, anti-nukes, the slide fix and the pad exit.

## 3. The AI's base layout and reach (M)

- **The gap:** the AI's site picker (`spotNear`) doesn't check that a builder can reach the site. Its 2-cell lanes only hold between buildings of one size.
- **What happened:** with footprint-2 Commanders (S-124) and pad exits (S-133), a Commander got walled in by generators. S-133 added a give-up (20 s without getting closer), but that's a safety net, not a layout.
- **Proposal:**
  - check reach for the builder's move class when picking a site (one flow field from the builder, cached per think);
  - keep a 2-cell ring free around factories' exits;
  - lay out mixed sizes on a coarser grid.
- The mirror-fairness test is the guard: the slide fix showed how easily that split moves.

## 4. Own units off camera (S–M, a wire change; B's question)

- **The gap:** strategic records carry only cell, type and flags. So the owner's units off camera keep their last health, build progress and factory queue.
- **Proposal:** a slim owner-only record (health u8, build u8, queue head and progress) for own units that left the tactical tier, sent on change and capped per tick. It needs your word on whether the extra bytes are worth it.

## 5. Remaining guide audit items (S each)

- non-square footprints (13);
- BEAM damage over time (16): lingering beams exist (S-113), but per-tick damage along the beam is still per shot;
- carriers building aircraft (5);
- a hover roster unit (4);
- a naval SAM platform and an advanced rearm pad (15);
- homing corrections more often than every 5 ticks for radar-only contacts (client request 11a);
- optional: terrain-occluded line of sight (11.2), elevation sight bonus (5.5).

## 6. Mirror fairness margin (S)

On Ridgeline, main splits 29 west / 31 east over 60 mirrored AI matches. That's fine, but the 12-match test passes at 4 / 8 and moved to 2 / 10 with a small movement change. Proposals:
- a longer fairness run in the slow suite (24 matches);
- a look at what still tilts east: snapping on exact half cells, ID order in the overlap pass.

## 7. New units and systems not in the audit (each a design decision first)

Transports, cloaking, capture, self-destruct, resurrect, veterancy, morph.

## Not planned unless asked

- **4-stud cells:** the wire's u16 cell caps maps at 256 × 256 (1024 studs at 4 studs a cell). Flow fields would cost about 4×, and footprints, the guide and every map would change.

---

## Done since the last list

- Commands at 800 units: options (a) and (b) (S-100, S-107); its peak is item 1.
- Phalanx shield domes (S-79..S-93), Wraith decoys (S-109).
- Normandy deposits (S-98); The Canyon (S-132).
- AI completeness: T2 builder, shields, Pinpointers, Barriers, Citadel, air and naval at Normal, T2 defences, nukes and anti-nukes (S-101, S-106, S-110, S-111).
- Balance pass (S-112); tooling: parallel reports and work counters (S-99).
- Cheats (S-102), in-place upgrades (S-108), anti-nukes (S-111), lingering beams (S-113..S-123), manual targets (S-115..S-127), ASSIST a builder (S-128).
- Radar blips: an orbit, then the cell, with a hidden aim point (S-130, S-131, S-134).
- Pad exits (S-133); the slide fix (S-135); IDLE events (S-136); group moves (S-137); queues in unfinished factories (S-138); the flying sight bonus (S-139); the watchdog (S-140).
