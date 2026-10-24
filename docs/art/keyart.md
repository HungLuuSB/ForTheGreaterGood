# Key art style guide

The style for the three loading-screen key arts. Built from the user's review of key art 1 (2026-10-23) and their reference images (a tank and fighter breaking out of a burning beach under a stormy sky; a stealth tank crashing through a ruined street with gunships overhead; a fighter firing a missile over a coastline under black smoke; a destroyer at speed under fighters, a patrol plane, a helicopter and flak bursts). The references set the mood, depth and VFX density only: nothing is copied from them, from BAR or from any other game.

Delivery format (layers, sizes, tiles, manifest): the lobby stream's contract `docs/contracts/key-art.md` (on `m-lobby`, decision L-13). Unit look: [`style-guide.md`](style-guide.md). Production: `assets/keyart/keyart.py` (Blender 5.2, Cycles).

## 1. The look in one paragraph

A cinematic still from the middle of a battle, not a game screenshot. Camera low among the units, wide lens, a dusk sun low behind the enemy line: backlit silhouettes, rim light, long shadows, warm orange sky against cool blue shadows, haze thickening with distance. Thick white SAM smoke curving across the sky, black smoke columns leaning with the wind, layered explosions throwing sand. One close aircraft banking toward the camera. Both factions readable at a glance, even as a thumbnail. Everything lit by what is in the scene: the sun, the fires, the muzzle flashes, the glows.

## 2. Rules

**Composition**

- Camera low, at ground eye height (about 4–6 studs over the ground), wide lens: 24–28 mm full-frame equivalent.
- Four planes of depth, and every picture uses all four: **foreground** (rocks, a wreck, dry grass, slightly out of focus; plus the close aircraft), **middle ground** (the main clash and the hero unit), **background** (the coast, the ships, smoke columns), **sky** (aircraft, SAM trails, the sun).
- **One focal point**, off-centre (on a third), never in the top text band or the bottom 25 % (the loading screens put text there). The trails, the tank lines, the smoke and the light lead the eye to it.
- Scale from front to back: something big and close, units of every size between, tiny units far away.
- Density: many units and effects, but grouped in masses (a tank line, a cluster of smoke, a fan of trails) with calmer areas between them. No even scatter.

**Light**

- Dusk: the sun 3–8° above the horizon, **behind the enemy line** (in frame or just outside it), so the enemy is backlit and our side is rim-lit.
- A warm key from the sun, a cool blue fill from the sky (shadows read blue, never black). Long shadows toward the camera.
- Haze grows with distance (aerial perspective): warm toward the sun, cooler away from it. God rays through the smoke where the sun shines through gaps.
- Fires and explosions light the units and the ground around them (real lights, not only emission).
- Faction glows stay visible: cyan on Order, amber on Chaos.

**Factions** (the meshes' own materials; never repaint them for the art)

| | Order | Chaos |
|---|---|---|
| Paint | sand / off-white (184, 178, 160) | gunmetal (96, 100, 106), near-black trim |
| Glow | cyan (90, 210, 255), heads ice-white | amber (255, 140, 50) |
| Team colour | blue (64, 132, 230) | red (222, 70, 62) |
| In the light | rim-lit, front faces in cool fill: reads light | backlit silhouettes: reads dark, the amber glows pop |

- At thumbnail size (256 px wide) each side must still read: a light mass with cyan sparks on one side, a dark mass with amber eyes on the other.
- At least **6 distinct unit types per side**, T1 and T2, from ground, air and naval (section 5). One **v3 Commander mech** (`ord_sovereign` or `chs_warlord`) stands as the hero in the middle ground.

**Destruction**

- Wrecks of both factions (the `export_wreck` meshes), some burning; craters; scorch marks; track marks in the sand; debris scattered; at least one destroyed structure (a toppled radar, a broken turret); several smoke columns rising out of the battle.

**Content limits**

- Only our meshes and our procedural materials. Extras only if CC0 (for example Poly Haven skies or textures), listed in section 8 with their source, and downloaded only after the user says yes. Nothing from BAR or any other game.
- No text, logos or UI in the art.

## 3. Palette

| Use | RGB |
|---|---|
| Sky near the sun | (255, 168, 84) |
| Sky at the horizon away from the sun | (232, 124, 70) |
| Upper sky | (78, 86, 118), blue-violet |
| Cloud undersides | (90, 70, 72) |
| Shadows (fill) | (44, 60, 92) |
| Haze toward the sun / away | (226, 158, 104) / (128, 136, 156) |
| Desert sand, lit / shaded | (198, 172, 128) / (120, 104, 84) |
| Scorched ground | (34, 28, 24) |
| Sea | (20, 48, 60), reflections of sky and fire |
| Fire core / fireball / edges | (255, 244, 220) / (255, 150, 50) / (150, 40, 10) |
| Black smoke → aged smoke | (26, 24, 22) → (110, 104, 98) |
| SAM smoke, shaded / sun side | (236, 236, 240) / (255, 220, 176) |
| Tracers: Order / Chaos | (255, 214, 140) / (255, 110, 50) |

## 4. VFX recipes

All smoke, fire, dust and haze are Cycles volumes (biased ray marching, `volume_biased`, so thousands of volumes fit in memory). Puffs are spheres with a noise × spherical-gradient density, so their edges are ragged, never round.

**SAM trail.** The path comes from a pursuit simulation: launch near-vertical off the rail, then turn at a limited rate toward a lead point on a moving target, so each trail curves where its missile turned and no two are alike.
- Width: a big billowing launch cloud at the launcher (3–4× the trail width, low and wide), then a tight bright line at the missile, swelling with age to 3–4× wide.
- Smoke white and dense when fresh, softer in the middle, thin and breaking into gaps when old; it drifts downwind and wavers more the older it is. Lingering older trails from earlier launches hang in the sky, thin and drifting.
- Lit by the sun: warm on the sun side, cool white in shade. No grey ropes.
- The missile: its mesh, a flame and a bright exhaust glow inside the fresh smoke, a small light.
- Several trails converge on the aircraft; at least one hit ends in a flak burst (below).

**Explosion**, built in layers, sizes from small hits to one huge one:
1. a white-hot core flash (emissive, with a strong short-range light);
2. the fireball: lobes of fire, white-yellow inside, orange, a dull red edge, wrapped in black soot;
3. sand and dirt thrown up in columns (it's a desert: tall sand plumes, not just fire), falling back as a curtain;
4. a dust shockwave ring rolling out along the ground;
5. sparks (short streaks, orange, not white);
6. debris chunks (irregular shards, not cubes), some with small smoke trails;
7. a smoke column that leans with the wind and lasts;
8. the light: an orange point light at the fireball that lights the nearby units and ground; the crater and scorch under it.

**Flak burst / interception.** A ragged fireball, a black soot puff, 2–4 thick smoke tendrils thrown outward and curving down, fragments, a ring of sparks.

**Aircraft hit.** A big fireball where it was hit, the wreck mesh falling out of it trailing fire and a thick black smoke trail, burning fragments arcing away.

**The close aircraft.** In the foreground, 25–35 % of the frame width, banking toward the camera at about 30°. Afterburner flame and glow, light motion blur (object motion blur from a short keyframed move, shutter about 0.3), its own vapour or smoke trail. A wingman further back; other aircraft at several distances.

**Tank fire.** The muzzle flash on the real barrel tip (the shooter turned onto its target): a white-hot flash, a tongue of flame, muzzle-brake side jets, a light, dust kicked off the ground ahead. Rounds in flight are small hot heads with a short streak tapering to nothing, in warm tracer colours; few in the air, most of the story in flashes and impacts. Impacts: sparks and a small dust puff.

**Naval.** The sea is a real band of the frame:
- water with waves (an ocean displacement near the shore, a bump-mapped plane farther out), reflecting the sky, the fires and the flashes;
- wakes (a foam V behind each moving ship and spray at the bow);
- broadsides: several guns flashing at once along the side, big flashes and gun smoke;
- shells arcing in and landing on the beach and the enemy line, impacts on land, water splashes near the shore;
- one ship burning, under a smoke column.

**Haze and atmosphere.** Aerial perspective from each pixel's depth (the mist pass), never a flat per-layer tint, so the haze is continuous across the layers. Low ground smoke and dust banks. God rays from the sun through gaps in the smoke. Embers drifting in the foreground.

## 5. Units for key art 1

At least these, from the approved and review meshes (the art may show review meshes):

| | Order | Chaos |
|---|---|---|
| Hero | `ord_sovereign` (v3 mech) | (`chs_warlord` for another art) |
| Tanks | `ord_paladin`, `ord_lancer` | `chs_ravager`, `chs_minotaur`, `chs_juggernaut` |
| Artillery / heavy | `ord_warden` in the deployed pose | `chs_cyclops` |
| Air defence | `ord_seraph`, `ord_vigil` | `chs_thorn` (IR SAM); `chs_hydra` (MLRS) firing rockets |
| Shield / beam | `ord_phalanx` (shield dome) or `ord_radiance` (beam tower) | `chs_carapace` or `chs_inferno` |
| Air | `ord_falcon` (the close fighter), `ord_absolution`, `ord_guardian` | `chs_harpy`, `chs_plague`, `chs_wasp` |
| Naval | `ord_dominion`, `ord_crusader` | `chs_kraken`, `chs_corsair` |
| Wrecks | `export_wreck` of both sides' tanks and aircraft | |

## 6. Layers

The contract's four layers: `sky` 0.08, `far` 0.3, `mid` 0.6, `near` 1.0; each 2048 × 1152 with 5 % bleed; 2 × 2 tiles. Maximum shift (2.5 % of the width × depth): near 51 px, mid 31, far 15, sky 4 at 2048 wide.

1. **One scene, one camera.** The camera's field of view covers the bleed (the visible frame is the middle 90 %).
2. **Layer by camera visibility, not by hiding.** For each layer render, only that layer's objects are visible to the camera; all other objects stay in the scene as shadow casters, light sources and reflections (`visible_camera = False`). Light, shadows and reflections are then the same in every layer.
3. **Each layer holds everything behind its nearer layers.** Because nearer objects are camera-invisible in a layer's render, the content behind them is there; when the near layer shifts, the revealed area is filled. No holes.
4. **Ground and water overlap and feather.** A layer's ground runs from in front of the camera to its back boundary, and fades to transparent over its last 10–15 % of distance, where the next layer's ground (the same terrain, material and light) continues. No strips with hard edges. The horizon, the sea and the far coast are wholly in `sky`, so the horizon is one continuous line.
5. **Objects belong to one layer by where they stand.** An object never straddles a boundary as a cut; a smoke column rising from the middle ground is all `mid`.
6. **Soft, clean alpha.** Volumes and glows fade to zero alpha; straight alpha in the PNG with no dark halos (colour un-premultiplied, bleeding past the edge).
7. **Depth of field and motion blur** only on the foreground (`near`): focused on the close aircraft, so the nearest rocks and grass go slightly soft; the aircraft's afterburner and trails are parented to it so they blur with it.
8. **One ground per render.** The per-layer ground copies would shadow each other (shadow acne), so each layer render switches on only its own ground; the single render uses only the full ground.
9. **Haze in order.** The haze volume starts at the `sky` layer's distance, so it sits behind every nearer layer in the single render too.
10. **Linear, then display.** Layers render to linear EXR (premultiplied). Each is converted to display colour from its straight colour through the scene's own view transform (a 3D table sampled from Blender's colour management), never from premultiplied colour (which brightens thin smoke and outlines it). Each layer's opacity is then solved against what lies behind it at rest, so the display-space stack the viewer draws reproduces the true blend; only translucent pixels change, and only in opacity, so the layers still look right when they slide apart. The bloom stays light: a screen effect can't sit in front of the nearer layers.
11. **The parallax test.** Composite the four layers at rest and at the maximum offsets (left, right, up, down): at rest the composite matches a single full render of the scene (the difference is noise, plus the foreground's blur); at the extremes there are no gaps, no doubled edges, and the horizon stays continuous. Output: the frames and a strip (no GIF encoder on this machine).

Production: `assets/keyart/layout.py` (step 2 sheets), `assets/keyart/ka1.py` (`light` for step 3; `final` for step 4, `--only <layers>` re-renders some layers from the cached linear ones).

## 7. Process (per key art)

Each step is shown to the user, who gives an OK before the next.

1. This guide.
2. Three rough layout options: grey blockout renders (no VFX) showing the camera, the focal point and where the units sit. The user picks one.
3. A lighting pass of the chosen layout: low samples, smoke and fire as rough volumes.
4. The final: the composite at 1024 × 576 and 2048 × 1152, the four layers, the parallax test. Checked against section 9, each item reported, before it's shown.

Uploads only with the user's approval. Then the `keyArt` table in the manifest (contract section 3).

## 8. Third-party assets

None. (Any CC0 sky or texture is listed here with its source and licence before use.)

## 9. Self-check

Report each item, yes or no, with a crop or note, before showing a final.

- [ ] Composite at rest = a single render (difference image is noise only).
- [ ] Parallax frames at the maximum offsets: no gaps, no doubled edges, no hard layer edges; horizon continuous.
- [ ] Clean alpha on every transparent layer: no halos, smoke and glows fade to zero.
- [ ] Camera low, wide lens (24–28 mm); four planes of depth all used.
- [ ] One focal point, off-centre, outside the top band and the bottom 25 %; the lines lead to it.
- [ ] Dusk sun low behind the enemy line; backlit silhouettes, rim light, long shadows; warm sky, cool shadows; haze grows with distance.
- [ ] Factions read at 256 px wide: Order light with cyan, Chaos dark with amber, team colours visible.
- [ ] At least 6 distinct unit types per side, T1 and T2, ground, air and naval; the v3 Commander as the hero.
- [ ] The close aircraft: 25–35 % of the width, about 30° bank toward the camera, afterburner, motion blur, its trail; a wingman; aircraft at several distances; one hit and trailing fire.
- [ ] SAM trails thick, white and billowing, wide at the launcher, curving, breaking up with age, warm on the sun side; several converge on aircraft; one hit ends in a flak burst.
- [ ] Explosions layered (core flash, fireball with sooty edges, sand columns, dust ring, sparks, debris with trails, leaning smoke columns); sizes from small to one huge; they light the units and ground.
- [ ] Destruction: burning wrecks of both sides, craters, scorch, track marks, debris, one destroyed structure, smoke columns.
- [ ] Navy: a real band of sea with reflections and wakes; broadsides with big flashes; shells landing on the beach and the line; splashes near the shore; one ship burning.
- [ ] Tracers small, warm and short; no rods.
- [ ] Only our meshes and CC0 extras listed in section 8; no text or logos.
- [ ] Sizes: layers 2048 × 1152, tiles 1024 × 576 named row by row from the top left; composites at 1024 × 576 and 2048 × 1152.

## Changes

- 2026-10-24: layer rules 7–11 from making key art 1 (one ground per render, haze order, linear-to-display with solved opacity, light bloom); the user's lighting review: no frontal fill (backlit, warm rim, cool sky light, contact shadows), glows at half strength, highlights rolled off so nothing clips to a flat white blob.
- 2026-10-23: first version, from the user's review of key art 1. Supersedes the earlier daytime previews (`assets/keyart/*_preview`, never uploaded). The contract's "SAM site at night" mood for key art 2 is now dusk per this guide; to be confirmed with the lobby stream when art 2 starts.
