# Contract: effect assets (FX)

Owner: models stream (the assets). Readers: the client stream, which builds the effects and animates them. Source: the user's request of 2026-10-22 (deployable shield, Order); `assets/fx/<effect>/build.py` makes every asset, `assets/fx/<effect>/roblox_assets.json` lists the uploaded IDs.

General rules:
- **Every effect asset is white or greyscale.** The client tints it with the team color at runtime (`TeamColors(team)`, as for unit team color, rig.md 6). Nothing is baked in a team color.
- **Meshes are imported MeshParts.** A MeshPart's origin is the center of its mesh's bounding box, so each entry below says where that center sits relative to the shape's natural pivot. Set `CanCollide`, `CanQuery`, `CanTouch` = false and `CastShadow` = false on every effect part.
- **Textures** are PNG with a transparent background; the shape is in the alpha, the color is white.
- The models stream keeps the source copies in "FTGG Art" under `ReplicatedStorage.FX.<Effect>`; copy them into the game place (they reference uploaded assets, so they work in any place of the same creator).

## Unit glow (every BAR-style mesh, M-22)

Every BAR-style unit and structure mesh carries its glow in **glow parts**: small MeshParts holding only the glowing faces, one per glow channel per piece, welded to that piece. No `Light` objects anywhere in the models. The pieces themselves don't glow (`EmissiveStrength` 0).

**How to find them:** CollectionService tag `Glow`; each glow part has the attributes `GlowChannel` (`running`, `head`, `power` or `weapon`), `GlowPiece` (the piece it's welded to, e.g. `turret`), `GlowTint` (Color3) and `GlowStrength` (number, the resting strength). Their names are `<piece>_glow_<channel>`. They're decorations by rig.md 1 (welded, unanchored, no collisions, no shadows), so they follow their piece's `Motor6D.Transform`.

**What to drive:** only the glow part's `SurfaceAppearance.EmissiveStrength`. A glow part has no color map: its `BasePart.Color` is its albedo and equals its tint, and its `EmissiveTint` is the same color (Roblox multiplies emission by the albedo, so a white albedo clipped every glow to white in daylight). Its `EmissiveMaskContent` is one shared white image (`Meshes.glowMask`, rig.md 7), since the part holds only glowing faces; without a mask Roblox doesn't emit at all. Glow parts use `RenderFidelity.Precise` (level of detail dropped thin strips spread over a large part). To change a channel's hue, set `Color` and `EmissiveTint` together; never paint a glow part with the team color. Glow is **never team-colored**, and team color stays on the painted panels (rig.md 6).

| Channel | What glows | Order tint | Chaos tint | Resting strength | Intended states (client) |
|---|---|---|---|---|---|
| `running` | sensor strips and eyes, tail and edge lights, engine exhaust slots, radar faces | cool cyan (90, 210, 255) | amber (255, 150, 55) | 2.0 | Always on while the unit exists. Optional: off for a dead / wreck model. |
| `head` | headlights and work lights (vehicles) | warm white (255, 236, 205), both factions | same | 2.5 | Always on. |
| `power` | structure cores, generator bands, extractor rings and vents, solar charge strips, factory door and build lights; on builders (Mason, Scrapper, shield emitter) the build / field emitter | cyan-white (130, 225, 255) | orange (255, 125, 35) | 2.5 | Structures: scale with the team's power ratio on an energy stall (e.g. `2.5 × ratio`, floor 0.3). Factories: pulse while producing (e.g. 1.5–4 at 1 Hz). Builders: brighten while building (≈ 4). |
| `weapon` | muzzle rings and brake bands, barrel rail strips, missile seekers and ready lights | ice white (190, 240, 255) | hot orange (255, 175, 70) | 1.5 | Flash on fire (≈ 6, back to 1.5 over ≈ 0.3 s); missile ready lights may drop to 0 while reloading. |

**Glow parts per model** (every BAR-style mesh; the same data is in the mesh manifest, `src/shared/Defs/Meshes/Registry.luau`, rig.md 7). A strength in brackets differs from the channel's resting strength. `running` and `head` have no client states beyond on; `power` and `weapon` are the driven ones.

| Model | `running` | `head` | `power` | `weapon` | Glow share |
|---|---|---|---|---|---|
| `chs_extractor` | `base_glow_running` | – | `base_glow_power` | – | 4.9% |
| `chs_generator` | `base_glow_running` | – | `base_glow_power` | – | 8.9% |
| `chs_hellmouth` | `base_glow_running`, `turret_glow_running` | `base_glow_head` | – | `barrel_glow_weapon` | 4.2% |
| `chs_hornet` | `base_glow_running` | `base_glow_head` | – | `launcher_glow_weapon` | 3.3% |
| `chs_jackal` | `base_glow_running` | `base_glow_head` | – | `turret_glow_weapon` | 3.7% |
| `chs_ravager` | `base_glow_running`, `turret_glow_running` | `base_glow_head` | – | `turret_glow_weapon`, `barrel_glow_weapon` | 3.4% |
| `chs_scrapper` | `base_glow_running` | `base_glow_head` | `nano_glow_power` | – | 3.8% |
| `chs_solar` | `base_glow_running` | – | `base_glow_power` | – | 3.4% |
| `chs_spike` | `base_glow_running`, `turret_glow_running` | – | – | `turret_glow_weapon` | 2.1% |
| `chs_vehplant` | `base_glow_running` | – | `base_glow_power` | – | 2.0% |
| `chs_watcher` | `base_glow_running`, `dish_glow_running` (1.4) | – | – | – | 8.8% |
| `ord_bulwark` | `base_glow_running`, `turret_glow_running` | – | – | `turret_glow_weapon` | 3.2% |
| `ord_extractor` | `base_glow_running` | – | `base_glow_power` | – | 7.5% |
| `ord_generator` | `base_glow_running` | – | `base_glow_power` | – | 7.7% |
| `ord_halo` | `base_glow_running`, `launcher_glow_running` | `base_glow_head` | – | `launcher_glow_weapon` | 3.7% |
| `ord_herald` | `base_glow_running`, `turret_glow_running` | `base_glow_head` | – | `turret_glow_weapon` | 4.2% |
| `ord_lancer` | `base_glow_running`, `turret_glow_running` | `base_glow_head` | – | `barrel_glow_weapon` | 4.9% |
| `ord_mason` | `base_glow_running` | `base_glow_head` | `nano_glow_power` | – | 6.0% |
| `ord_oracle` | `dish_glow_running` | `base_glow_head` | – | – | 2.1% |
| `ord_solar` | `base_glow_running` | – | `base_glow_power` | – | 4.2% |
| `ord_vehplant` | `base_glow_running` | – | `base_glow_power` | – | 3.4% |
| `ord_verdict` | `base_glow_running`, `turret_glow_running` | `base_glow_head` | – | `barrel_glow_weapon` | 5.1% |
| `shield_emitter` (FX.Shield.Emitter) | `base_glow_running` | – | `base_glow_power` | – | 9.9% |

**Team colors that clash with a faction glow** (checked with all 8 lobby colors of `src/client/Render/TeamColors.luau`, 55° close and 220 studs, normal and dusk; `debug_out/screens/glow2_team_*.jpg`). The user keeps all 8 team colors; for these pairs the client switches that unit's `running` and `power` glow to white (`Color` = `EmissiveTint` = (235, 240, 245), strengths unchanged). `head` is warm white already, and `weapon` flashes stay as they are:

| Team color | Faction | Clashes with | Switch |
|---|---|---|---|
| 7 cyan (60, 200, 210) | Order | `running` cyan (90, 210, 255), `power` (130, 225, 255) | yes: team panels read as glow strips |
| 6 orange (238, 132, 40) | Chaos | `running` amber (255, 150, 55), `power` (255, 125, 35) | yes: panels and glow merge into one color, the accents vanish at 220 studs |
| 4 yellow (232, 196, 52) | Chaos | `running` amber | borderline, no switch: reads apart (yellower, brighter); the client's call |

Blue on Order and red on Chaos read apart (darker, more saturated than the glow). Other pairs don't share a hue.

**Coverage** (glow area as a share of the surfaces that don't face down, in each `rig.json` as `glowShare`): 2–9% (table above): most units and structures 3–8%; the Spike turret and the Oracle (since its array face went dark) about 2%; the vehicle plants 2–3.5% (big roofs). The art rule is in `docs/art/style-guide.md` ("Glow").

**Cost:** 1–4 extra MeshParts per model, a few dozen triangles each, sharing the unit's maps; nothing animates unless the client changes a property.

## Wrecks (BAR-style meshes, M-24)

Every approved meshed unit and structure has a wreck version: `Meshes.units.<id>.wreck` (rig.md 7). It has the live mesh's pieces and pivots with its own meshes and maps:
- dented and bent, with small fittings blown off;
- darkened and sooted;
- **no glow parts:** the sockets are dead and dark, so drive no channels on a wreck;
- **no team color:** the panels are scorched grey; the alpha is 1, so the team tint doesn't show even with `AlphaMode.Overlay`.

To show one, build it like the live model with the wreck's `pieces[name].mesh` / `center` / `size` and `maps`, and skip `glow` and `teamPieces`. Keep the joint pose the death left (turret turned, barrel drooping); no color lerp or `CorrodedMetal` is needed. Aircraft shot down in flight leave no wreck (net.md 5), but a landed one can.

## Missiles (BAR-style meshes, the user's request 2026-10-22)

One mesh per missile weapon def, by its ID: `ord_ir_sam`, `chs_ir_sam`, `ord_radar_sam`, `chs_radar_sam`, `ord_nuke`, `chs_nuke`. They're listed in the mesh manifest under `fx` (`Meshes.fx.<weapon id>`: piece `base`, maps, glow parts, status; rig.md 7). Each replaces the primitive missile parts in `Render/Effects.luau`; the client keeps drawing the flame, the light and the smoke.

- **Frame:** forward = −Z, the middle at the origin, 4.4 studs from the tip (z = −2.2) to the nozzle (z = 2.2). That's the client's 1× style frame, so the client scales it the way it scales its own parts: IR SAMs ×1 (`smoke_thin`), radar SAMs ×2.3 (`smoke_thick`), strategic missiles ×4.5 (`smoke_huge`). Scale `Size` and positions together.
- **Looks:**
  - IR SAM: slim, with a dark IR seeker dome, canards and tail fins (Chaos: three tail fins).
  - Radar SAM: thicker, with an off-white radome, long mid-body strakes and tail fins.
  - Nuke: a heavy body with a dark re-entry cone over a warhead bus, stage rings and four fins (Chaos: two strap-on boosters).
  - All three: faction paint and a team band (`teamPieces` = `base`), tinted like a unit.
- **Glow:** a `running` stripe round the body (faction accent), at its resting strength. The nozzle throat is dark: the client lights the exhaust (user review 2026-10-23, no `weapon` glow part any more).
- **Interceptors** (anti-nuke, S-111): `ord_interceptor` / `chs_interceptor`, and the mobile launchers' `ord_mobile_interceptor` / `chs_mobile_interceptor` reuse the same meshes (the manifest lists all four IDs). Fast and slim: a needle nose (Order white radome, Chaos dark) on a fatter booster, canards and booster fins. Unlike the other missiles, the nozzle throat glows bright on `weapon` (strength 3.0), so an interceptor reads at a glance; the client still draws the flame.

## Supply deposits (M-28)

The supply deposits drawn as part of the terrain, BAR metal-spot style: no neon, no glow, nothing that reads as UI. `Meshes.fx.deposit` is a normal fx entry (variant 1's fields) with `variants = { v1, v2, v3 }`, each a full entry with its own model, `pieces.base`, maps and triangles (536–552 each). Status "review" until the user approves.
- **Look:** a shallow scraped patch with a ragged edge, a darker scraped-soil core under an off-centre cluster of ore outcrops (dark rock, metallic ore tops: metalness and roughness only), a broken berm of low lumps and loose stones at the edge.
- **Size:** fits one 8-stud cell (about 7 across, origin on the ground at the deposit cell's centre), at most 0.7 studs tall. A T1 extractor (2 × 2) covers it whichever of its quadrants sits over the deposit, and a T2 (3 × 3) is centred on it. Extractor bases are at least 0.7 thick over the whole footprint, so the deposit disappears under them.
- **Placement:** pick a variant and a random yaw per deposit, so a map's deposits don't look stamped.
- **Terrain tint:** the outer patch is under the alpha mask (`teamPieces = { "base" }`). Set `BasePart.Color` to the plain terrain colour (grass, sand, rock), not a team colour. The mask darkens it to about 60–75% of the terrain, so the spot reads as darker ground on every map. The core, rocks and ore keep their own colours.
- **MeshMaterials:** one SurfaceAppearance per variant (`variants[i].maps`).

## Effect textures (M-27)

White RGB with the pattern in alpha, 512 × 512, so the client tints them (fx colors, faction accents). They're in the mesh manifest as `Meshes.textures` and built by `assets/fx/textures/build.py`.

| Key | Asset | Look | Use |
|---|---|---|---|
| `radarPulse` | `rbxassetid://113771866546969` | a bright thin ring with a soft glow trailing inward | radar sweep pulse: grow a flat disc outward from a turning radar and fade it |
| `sonarPing` | `rbxassetid://120009987380670` | two soft concentric rings | sonar ping: expand on the water surface and fade |
| `jammerStatic` | `rbxassetid://124485150689074` | tileable speckle and scan lines | jammer shimmer / static on a sphere or a cylinder round a jammer, scrolled |
| `heatShimmer` | `rbxassetid://105647146631109` | tileable soft wavy bands, low alpha | heat shimmer over exhausts, stacks, reactors and beam emitters, scrolled upward |

## Beam shot (Radiance / Inferno, M-29)

The beam towers' shot (`ord_radiance_beam`, `chs_inferno_beam`; the weapons' `fx.muzzle = "beam_charge"`, `fx.impact = "beam_impact"`), BAR Pulsar style but original: a bright laser from the muzzle to the target with thin crackling energy filaments racing along it, thinning and gone within about half a second. Textures are white (the scorch is grey), so the client tints them: Order ice-white / cyan, Chaos hot orange. They are in the mesh manifest as `Meshes.beam` (status `review`): `textures` plus the recommended values per faction under `factions.order` / `factions.chaos`, all listed below. Built by `assets/fx/beam/build.py`.

**Reference build:** "FTGG Art", `Workspace.BeamFxReference`: a Radiance lane and an Inferno lane, each tower firing at a `DummyTarget` 100 studs away, driven by the ModuleScript `BeamFxReference.BeamShot`. `BeamShot.build(faction, muzzle, hit, groundY)` makes every instance once; `BeamShot.apply(rig, t)` sets them all for `t` seconds after the shot started (a pure function of `t`: the same `t` gives the same frame); `BeamShot.play(rig)` loops it as a preview. The same module is in the repo as `assets/fx/beam/BeamShot.luau` (not synced): copy `build` and `apply` into the client's beam effect.

### Textures

Roblox Beams lay a texture's width along the beam: the strips below run along X (the beam's length) and tile in X; Y runs across the beam.

| Key | Asset | Size | Look | Use |
|---|---|---|---|---|
| `core` | `rbxassetid://84580715736855` | 512 × 64 | flat-topped soft core with a hot centre line, a faint ripple along X | Beam `BeamCore`, `TextureMode = Wrap` |
| `glow` | `rbxassetid://140653615912799` | 512 × 64 | wide faint haze, zero at the edges | Beam `BeamGlow`, wider than the core |
| `filamentA` | `rbxassetid://130559041254740` | 1024 × 128 | three thin crackling lines that wander across the strip, with gaps and flicker | odd filament Beams, scrolled fast (`TextureSpeed`) |
| `filamentB` | `rbxassetid://71590951128896` | 1024 × 128 | two lines on a different wave and seed | even filament Beams, so stacked filaments don't sync |
| `charge` | `rbxassetid://95187819936446` | 512 × 512, 2 × 2 flipbook (256 px frames, reading order) | a tight glint opening into a four-ray star | charge flare at the muzzle: a BillboardGui `ImageRectOffset` per frame, or a ParticleEmitter with `FlipbookLayout = Grid2x2`, `FlipbookMode = OneShot` |
| `impact` | `rbxassetid://121983330106046` | 512 × 512 | hot core, uneven rays, a soft shock ring | impact flare at the hit point |
| `scorch` | `rbxassetid://108024950155994` | 512 × 512 | dark grey soot blotch with radiating streaks (greyscale RGB, **not** tinted) | ground Decal under the hit point |
| `scorchGlow` | `rbxassetid://83492274682254` | 512 × 512 | a broken ember rim and a hot centre (white) | Decal over the scorch, tinted with the glow color, fading in the first second |

### Timing (t = seconds since the shot started)

| t (Order) | t (Chaos) | What happens |
|---|---|---|
| 0 – 0.08 | 0 – 0.06 | **charge:** the `charge` flipbook at the muzzle, frames 1 → 4, growing from 55% to 100% of `flareSize`; it fades over the next 0.04 s |
| 0.08 | 0.06 | **beam on at full width:** core, glow and the filaments; the impact flare starts at the hit; the scorch appears 0.02 s later |
| 0.08 – 0.12 | 0.06 – 0.09 | **hold** at full width (`hold`) |
| 0.12 – 0.50 | 0.09 – 0.36 | **taper** (`taper`), with `u` going 0 → 1: core width × (1 − u)^1.1, transparency 0.7·u^1.6; glow width × (1 − u)^0.8, transparency 0.35 + 0.65·u; filaments thin faster: width × (1 − u)^2.2, transparency 0.8·u^1.2. At the end every Beam is disabled |
| 0.08 – 0.38 | 0.06 – 0.31 | **impact flare** (`impactTime`): grows to 120% of `impactSize` in the first quarter, transparency k^1.5 |
| to 1.3 | to 1.1 | **embers** (`scorchGlowTime`) fade out over the scorch |
| to 4.1 | to 3.1 | **scorch** (`scorchTime`) stays, fading over its last 1.5 s |

**Filaments, every frame (30 times a second):** each filament Beam has its own pair of attachments, near the muzzle and at the hit. Give each a new perpendicular offset round the beam axis: angle = its slot (i / n of a turn) plus a random ± `jitter` turn; radius `spread` × (0.6–1.0) at the muzzle and × `fan` (small) at the target, so the filaments leave the emitter spread round the core and converge on the hit. Also new random `CurveSize0` / `CurveSize1` within ± `curve` (`Segments = 16`). Seeded per shot and frame (`Random.new(seed + frame)`), so a replay looks the same.

**Every Beam:** `FaceCamera = true`, `LightEmission = 1`, `LightInfluence = 0`, `TextureMode = Wrap`. **The beam narrows to a point at the target** (the user's feedback, 2026-10-23): `Width0` (muzzle end) is the full width, `Width1` (target end) = `Width0` × `tip`, for the core, the glow and the filaments. Beams add up: keep `Brightness` low (below), or the overlap washes out to a flat white bar in daylight.

### Recommended values

Radiance is thicker and longer; Inferno shorter, hotter and more ragged.

| Value | Radiance (`order`) | Inferno (`chaos`) |
|---|---|---|
| `charge` / `hold` / `taper` (s) | 0.08 / 0.04 / 0.38 (beam gone at 0.50) | 0.06 / 0.03 / 0.27 (beam gone at 0.36) |
| core width / glow width at the muzzle (studs) | 1.6 / 7 | 1.2 / 5.5 |
| filaments: count, width at the muzzle (studs) | 4, 2.5 | 3, 2.2 |
| `spread` / `fan` / `jitter` / `curve` | 0.8 / 0.15 / 0.45 / 1.6 | 1.0 / 0.2 / 0.7 / 2.2 |
| `tip` (width at the target ÷ width at the muzzle) | 0.06 | 0.08 |
| core color | (225, 248, 255) ice-white | (255, 205, 150) white-hot |
| glow color | (80, 190, 255) cyan | (255, 85, 15) orange |
| filament color | (165, 232, 255) | (255, 130, 35) |
| `Brightness`: core / glow / filaments | 2 / 0.6 / 3 | 2.4 / 0.8 / 3.4 |
| `TextureLength`: core / glow / filament A / filament B (studs) | 30 / 60 / 20 / 15 | 24 / 50 / 16 / 12 |
| `TextureSpeed`: filament A / B (tiles per second) | 30 / 40 (about 600 studs/s) | 40 / 52 (about 640 studs/s) |
| `flareSize` / `impactSize` / `scorchSize` (studs) | 7 / 14 / 7 | 6 / 12 / 6 |
| `impactTime` / `scorchGlowTime` / `scorchTime` (s) | 0.3 / 1.2 / 4 | 0.25 / 1.0 / 3 |

The flares and the core use the core color, the embers the glow color. Check the manifest entry with `Mesh.validateBeam(Meshes.beam)`.

**Notes from the reference build:**
- **Embers glow through an overbright Decal color:** a Decal can't emit light, so set `Color3` to the glow color × 4 (`Color3.new(r * 4, g * 4, b * 4)`); at plain 0–1 values the embers read as dull paint.
- **Additive tints mix with the ground:** over green grass the Inferno's orange reads amber up close (orange + green); at 220 studs and on brown or dark ground it reads orange. Don't push the Chaos colors redder to compensate: on dark ground they would go red.
- **Fresh images stream in:** right after a texture is first used, Roblox draws a low-resolution version for a moment (the filaments look smeared), and a Beam whose image hasn't loaded draws as a flat bar. Preload the eight textures (`ContentProvider:PreloadAsync`) when the match loads.
- **`TextureSpeed`** only animates while the game runs (not in Studio's edit view), so the scroll direction isn't checked yet: the energy should travel from the muzzle (`Attachment0`) to the hit; if it runs backwards in a playtest, flip the sign of both speeds.

## Shield (Order deployable shield)

The target look: a translucent dome with a bright edge, thin glowing rings flowing from the top down the dome, a curved light beam rising from a small emitter device to the top of the dome, a swirling vortex at the top, floating specks inside, and a ring burst where a shell hits. `R` below is the dome radius in studs.

### Meshes (`ReplicatedStorage.FX.Shield`)

| Asset | Mesh | How to use it |
|---|---|---|
| `Dome` | hemisphere, radius 1, open bottom, smooth outward normals, 920 triangles; UVs: U round, V from the rim (0) to the top (1) | `Size = (2R, R, 2R)`; the part's center is half-way up: `CFrame = baseCenter * CFrame.new(0, R / 2, 0)`. `Material = ForceField` (its rim-bright look gives the bright edge), `Color` = team color. ForceField uses the part's `TextureID` (if any) as its pattern. |
| `DomeInner` | the same hemisphere at radius 0.96, normals **inward**, 920 triangles | The far wall seen through the dome: `Size = (1.92R, 0.96R, 1.92R)`, `CFrame = baseCenter * CFrame.new(0, 0.48R, 0)`, `Material = ForceField`, team color, usually a little more transparent than `Dome`. Optional. |
| `Ring` | thin torus, radius 1, tube radius 0.01, horizontal (axis = Y), 204 triangles | One ring of the flow: at height `h` on a dome of radius `R` the ring's radius is `r = sqrt(R² − h²)`; `Size = (2.02r, 0.02R·k, 2.02r)` (`k` thickens the tube, 1 = 1% of R), `CFrame = baseCenter * CFrame.new(0, h, 0)`. `Material = Neon`, `Color` = team color, `Transparency` fades it near the rim. Pool them and move `h` from `R` to 0. |
| `Emitter` | Model: `base` MeshPart (588 triangles, BAR style, Order sand-grey; SurfaceAppearance like the units), two glow parts (`base_glow_power`: the core, `base_glow_running`: the foot ring; "Unit glow" above) and an `Attachment` named `core` | The device the beam rises from. Unit origin on the ground under its center; the model carries `RootOffset` like a unit (rig.md 2): `base.CFrame = origin * model:GetAttribute("RootOffset")`. About 4 studs wide and 2.9 tall. Its `TeamColor`-tagged `base` takes the team color on its team plates (rig.md 6). The `core` attachment is the beam's start (top of the glowing core, 2.75 studs up). The core's glow is the Order cyan accent (M-16), not the team color; drive `base_glow_power` with the shield's charge if wanted. Built by `assets/fx/shield/emitter/build.py` since the glow pass. |

### Shield generators (blockouts)

The defs (S-79) are `ord_phalanx` (Order, footprint 2, dome radius 120) and `chs_carapace` (Chaos, footprint 2, dome radius 80), pieces `base` and `core`. In both blockouts `core` is the glowing part the beam comes from, and an `Attachment` named `beam` sits on top of it (Phalanx 8.3 studs up, Carapace 7.6): use it as the beam's `Attachment0` the way the `Emitter` model's `core` attachment is used. The bright ring where the dome meets the ground is one more `Ring` at `h` = 0 (`r` = `R`).

### Thin rings (client request, C-94)

A mesh's tube scales with its radius, so on a 120-stud dome the `Ring` above is a 2.4-stud ribbon. Two thinner meshes come in `assets/fx/shield/export/shield_rings.fbx` (`build_rings.py`; IDs below and in `roblox_assets.json`):

| Asset | Mesh | How to use it |
|---|---|---|
| `RingThin` | torus, radius 1, tube 0.002 (a fifth of `Ring`), horizontal, 288 triangles | As `Ring`: `Size = (2.004r, t, 2.004r)`; its radial thickness is 0.2% of the radius (0.24 studs at r = 120), `Size.Y` sets the vertical thickness. |
| `Band` | open cylinder wall, radius 1, height 1, faces both ways, 192 triangles; UV U round, V across | A flat ribbon whose width is set apart from its radius: `Size = (2.002r, w, 2.002r)` for a ribbon `w` studs wide at radius `r`, `CFrame = baseCenter * CFrame.new(0, h, 0)`. The wall is 0.2% of the radius thick. |

### The client's look (C-94)

The user's rules for the shield override parts of the table above: the dome is neutral white rather than team-colored, its opacity follows the charge (invisible at 0%, full from 50%), and it doesn't use the ForceField material. Every asset here is white, so these choices need no other assets.

### Textures

| Asset | Size | How to use it |
|---|---|---|
| `swirl` | 512 × 512 | The vortex at the top: a flat disc (e.g. a thin Part, `Size = (d, 0.05, d)`) at the dome's top with a `Decal` on its top face, `Decal.Texture` = swirl, `Decal.Color3` = team color; spin the disc about Y. |
| `beam` | 256 × 512 | The light beam from `Emitter.core` to the dome's top: a `Beam` with `Attachment0` = `core`, `Attachment1` at the top; `Texture` = beam, `TextureMode = Wrap`, `TextureLength` ≈ the beam's width × 2, `TextureSpeed` > 0 to scroll; `Color` = team color, `LightEmission = 1`, `FaceCamera = true`; `CurveSize0` / `CurveSize1` bend it. The strip runs along V (tiles vertically: seamless top to bottom); the core is the middle third of U. |
| `speck` | 256 × 256 | Floating specks: a `ParticleEmitter` (e.g. on the `Dome` part, `Shape = Sphere`, `ShapeInOut = Inward`), `Texture` = speck, `Color` = team color, `LightEmission = 1`, small `Size` (0.2–0.6), slow `Speed`. |
| `ripple` | 512 × 512 | A hit on the dome: one particle from a `ParticleEmitter` at the hit point, `Orientation = VelocityPerpendicular` with the velocity along the dome's normal (so it lies flat on the dome), `Speed` ≈ 0.01, `Emit(1)`; `Size` grows from 0 to the burst size, `Transparency` goes to 1; `Texture` = ripple, `Color` = team color, `LightEmission = 1`. |

### Asset IDs

All in `assets/fx/shield/roblox_assets.json`. The texture IDs are also attributes of the `ReplicatedStorage.FX.Shield` folder in "FTGG Art" (`Swirl`, `Beam`, `Speck`, `Ripple`).

| Asset | ID |
|---|---|
| `Dome` mesh | `rbxassetid://85081416332401` |
| `DomeInner` mesh | `rbxassetid://78950571354329` |
| `Ring` mesh | `rbxassetid://134054369788950` |
| `RingThin` mesh | `rbxassetid://111379471786973` |
| `Band` mesh | `rbxassetid://75299929805633` |
| `Emitter` mesh | `rbxassetid://81558546555311` (glow pass; glow meshes and maps in the JSON, `emitterGlow`) |
| swirl | `rbxassetid://113814321169730` (cloudy vortex, after the user's reference) |
| beam | `rbxassetid://100117547859650` |
| speck | `rbxassetid://90660161303538` |
| ripple | `rbxassetid://129891612158965` |

### Checked assembly

"FTGG Art", `Workspace.ShieldTest` at (−700, 0, −300): `R` = 40, team blue; `Dome` ForceField, `DomeInner` ForceField at 0.4 transparency, one `Ring` at h = 0.55R (`Size.Y` 0.35), the `Emitter`, a 16-stud swirl disc at the top, and a `Beam` from `core` to the disc (`Width0` 2.2, `Width1` 1.2, `CurveSize0` 18, `CurveSize1` −6, `TextureLength` 4). Screenshots: `debug_out/screens/shield_*.jpg`. Particles (specks, ripple) don't run in Edit mode, so they aren't in the shots. The emitter is about 4 studs across, small next to a 40-stud dome: scale its model if the generator needs a bigger device.
