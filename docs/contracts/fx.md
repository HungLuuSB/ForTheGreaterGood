# Contract: effect assets (FX)

Owner: models stream (the assets). Readers: the client stream, which builds the effects and animates them. Source: the user's request of 2026-10-22 (deployable shield, Order); `assets/fx/<effect>/build.py` makes every asset, `assets/fx/<effect>/roblox_assets.json` lists the uploaded IDs.

General rules:
- **Every effect asset is white or greyscale.** The client tints it with the team color at runtime (`TeamColors(team)`, as for unit team color, rig.md 6). Nothing is baked in a team color.
- **Meshes are imported MeshParts.** A MeshPart's origin is the center of its mesh's bounding box, so each entry below says where that center sits relative to the shape's natural pivot. Set `CanCollide`, `CanQuery`, `CanTouch` = false and `CastShadow` = false on every effect part.
- **Textures** are PNG with a transparent background; the shape is in the alpha, the color is white.
- The models stream keeps the source copies in "FTGG Art" under `ReplicatedStorage.FX.<Effect>`; copy them into the game place (they reference uploaded assets, so they work in any place of the same creator).

## Shield (Order deployable shield)

The target look: a translucent dome with a bright edge, thin glowing rings flowing from the top down the dome, a curved light beam rising from a small emitter device to the top of the dome, a swirling vortex at the top, floating specks inside, and a ring burst where a shell hits. `R` below is the dome radius in studs.

### Meshes (`ReplicatedStorage.FX.Shield`)

| Asset | Mesh | How to use it |
|---|---|---|
| `Dome` | hemisphere, radius 1, open bottom, smooth outward normals, 920 triangles; UVs: U round, V from the rim (0) to the top (1) | `Size = (2R, R, 2R)`; the part's center is half-way up: `CFrame = baseCenter * CFrame.new(0, R / 2, 0)`. `Material = ForceField` (its rim-bright look gives the bright edge), `Color` = team color. ForceField uses the part's `TextureID` (if any) as its pattern. |
| `DomeInner` | the same hemisphere at radius 0.96, normals **inward**, 920 triangles | The far wall seen through the dome: `Size = (1.92R, 0.96R, 1.92R)`, `CFrame = baseCenter * CFrame.new(0, 0.48R, 0)`, `Material = ForceField`, team color, usually a little more transparent than `Dome`. Optional. |
| `Ring` | thin torus, radius 1, tube radius 0.01, horizontal (axis = Y), 204 triangles | One ring of the flow: at height `h` on a dome of radius `R` the ring's radius is `r = sqrt(R² − h²)`; `Size = (2.02r, 0.02R·k, 2.02r)` (`k` thickens the tube, 1 = 1% of R), `CFrame = baseCenter * CFrame.new(0, h, 0)`. `Material = Neon`, `Color` = team color, `Transparency` fades it near the rim. Pool them and move `h` from `R` to 0. |
| `Emitter` | Model: `base` MeshPart (588 triangles, BAR style, Order sand-grey, cyan emissive core; SurfaceAppearance like the units) and an `Attachment` named `core` | The device the beam rises from. Unit origin on the ground under its center; the model carries `RootOffset` like a unit (rig.md 2): `base.CFrame = origin * model:GetAttribute("RootOffset")`. About 4 studs wide and 2.9 tall. Its `TeamColor`-tagged `base` takes the team color on its team plates (rig.md 6). The `core` attachment is the beam's start (top of the glowing core, 2.75 studs up). The core's glow is the Order cyan accent (M-16), not the team color. |

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
| `Emitter` mesh | `rbxassetid://98339625291172` (maps in the JSON) |
| swirl | `rbxassetid://113814321169730` (cloudy vortex, after the user's reference) |
| beam | `rbxassetid://100117547859650` |
| speck | `rbxassetid://90660161303538` |
| ripple | `rbxassetid://129891612158965` |

### Checked assembly

"FTGG Art", `Workspace.ShieldTest` at (−700, 0, −300): `R` = 40, team blue; `Dome` ForceField, `DomeInner` ForceField at 0.4 transparency, one `Ring` at h = 0.55R (`Size.Y` 0.35), the `Emitter`, a 16-stud swirl disc at the top, and a `Beam` from `core` to the disc (`Width0` 2.2, `Width1` 1.2, `CurveSize0` 18, `CurveSize1` −6, `TextureLength` 4). Screenshots: `debug_out/screens/shield_*.jpg`. Particles (specks, ripple) don't run in Edit mode, so they aren't in the shots. The emitter is about 4 studs across, small next to a 40-stud dome: scale its model if the generator needs a bigger device.
