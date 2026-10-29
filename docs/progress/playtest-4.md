# Playtest 4: what changed since playtest 3

Baseline: playtest 3 on `main` d06f303b (2026-10-29). Build: `lune run build` on `main` in `../FTGG-integration`, giving `build/ci/place.rbxl`. Not published: the user publishes. sim-A keeps this file.

## Units and balance (sim)

- **The Chaos T3 bot is now `chs_juggernaut` (S-213).** The old T2 Juggernaut is now `chs_goliath` and is retired: no factory builds it. The Chaos Advanced Vehicle Plant has no T2 main battle tank for now; the AI uses the Tzar.
- **Titan and Juggernaut (S-213, S-217):**
  - Their weapons reach less far.
  - Their self-destruct and death blasts are 52 studs wide (35% of a nuke's 150) and deal 480 damage, about 15% of a Commander's health. Before, a blast was almost as wide as a nuke and could kill a Commander outright.
- **Solar Array costs 100 supply (S-217).** It was 30.
- **Unit descriptions (S-214)** read "Role. What it does." They make no comparison with the other faction's version.
- **The power bar's demand (S-215)** now includes extractor upkeep and the power converters burn. Before, the bar could show a surplus while power ran out.

## Skirmish AI (sim, S-216)

- The AI now builds playtest 3's units:
  - bot labs and bots;
  - Construction Turrets next to its factories (Normal 1 per factory, Hard 2);
  - advanced solar once it has 6 solars;
  - fusion while power stalls;
  - converters;
  - offshore extractors on sea maps (a naval worker from an early shipyard);
  - on Hard, an Experimental Gantry that builds Titans or Juggernauts.
- The AI also goes to T2 by extractor count and match time, not only by stored supply. Before, an AI in a real match never stored supply, so it never got to T2.
- Mirror results on Supreme Strait and Coastline are in `debug_out/mirror_units.md` (`lune run mirror_units`).

## Client (B)

- Amphibious walkers walk on the seabed, and water is still (C-254, C-255).
- Pulse pieces swell with their glow (C-257).
- New icons, all from E's approved set:
  - unit icons for all 203 defs, including the 21 playtest-3 units;
  - resource and stat icons;
  - command-button icons on the command card.

  They are uploaded and wired in (C-258..C-261).
- Unit portraits use the new unit pictures (C-262). The re-rendered pictures and the faction emblems are uploaded (C-265, C-269).
- In-game effects use C's templates:
  - D-Gun effects (C-266, C-267);
  - the nuke, structure deaths and missile boosters (C-267);
  - soot and glow blast marks on the ground (C-268).
- The D-Gun's aim preview pulls the aim point into range; new command cursor; icon fixes (C-263, C-264).

## Models and effects (C)

- New effects (on `main`):
  - D-Gun bolt, muzzle, hit and end effects;
  - modern explosions, impacts and the nuke effect;
  - missile boosters;
  - blast-mark decals on the ground.
- Build-menu unit pictures: rendered in faction colours with no fog, then packed into sheets by E (E-11).

## 2D assets (E, new stream)

- New unit icon set, style B (E-1..E-6). Commander icons show their heads.
- Icons for resources (E-7), unit stats (E-8), weapons and details (E-9), and command buttons (E-10).
- 197 unit pictures on 4 sheets (E-11), and faction emblems, direction A (E-12).

## Lobby (D)

- The key art is picked at random (L-27).
- The Codex uses E's stat icons and the S-213 ids.

## Not in this build

- Transports: design only (`docs/design/transports.md`), waiting for the user's OK.
- The Construction Turret reclaiming live enemy units: proposal only, waiting for the user's OK.
