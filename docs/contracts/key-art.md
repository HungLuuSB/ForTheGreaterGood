# Contract: key art with parallax layers

Owner: lobby stream (session D). Maker: models stream (session C). Readers: one viewer, `src/client/UI/KeyArt.luau` (client stream B), used by the match place's loading screen (`UI/MatchLoading`) and, read-only, by the lobby's. Decision: L-13.

The user (2026-10-23): stunning key art from the models stream, with a parallax effect like the menu's live scene. A battle between tanks, aircraft and ships on the far side, SAM missiles flying, explosions on the ground. Realistic lighting, a battlefield feel, a sci-fi edge.

## 1. The pictures

| | |
|---|---|
| **What** | 3 key arts to start; the loading screens pick one at random |
| **Look** | the game's own approved meshes (Blender, as for the portraits), BAR key-art style, with the user's references: BAR's loading screens (a hero unit up close, the battle behind) |
| **Light** | realistic and dramatic: low sun or dusk, volumetric haze and god rays, rim light on the units, faction glow parts lit (sci-fi), warm explosion light on the ground and the smoke |
| **Content** | **mid-ground:** Order and Chaos tanks fighting (Paladin, Lancer, Ravager, Minotaur...), muzzle flashes, tracers, impacts and **explosions on the ground** with dirt and fire. **Air:** fighters and helicopters, **SAM missiles climbing on smoke trails** (Seraph, IR SAM), an interception burst or two. **Far side:** a sea with **ships** (Dominion, Kraken, Crusader...) firing, a coast, haze. **Foreground:** close dark shapes (rubble, a wreck, a tank's track or turret edge), smoke and embers |
| **Factions** | Order blue (64,132,230) and Chaos red (222,70,62) team paint, as in game |
| **Mood per art** | all three at dusk (the user's style guide, `docs/art/keyart.md` on m-models): 1. "Commander's stand", a land battle with the sea behind; 2. a SAM site under air attack; 3. a beach assault: ships, landing tanks, artillery |
| **Avoid** | text, logos and UI in the art; the screens put text in the top band and the bottom 25%, so keep heroes out of those bands |

## 2. Layers (for the parallax)

Each key art is 4 layers, back to front, rendered from **one camera** (the same framing, so they line up at rest):

| Layer | Depth | Holds | Alpha |
|---|---|---|---|
| `sky` | 0.08 | sky, sun, clouds, far coast and **the naval battle**, far haze | opaque |
| `far` | 0.3 | the far battlefield, aircraft and **missile trails**, distant explosions | transparent where empty |
| `mid` | 0.6 | the tank fight, ground explosions, the SAM launching | transparent where empty |
| `near` | 1.0 | foreground debris, the close wreck or hero edge, smoke, embers | transparent where empty |

- **Depth** is how far a layer moves with the mouse (1.0 = the most, about 2.5% of the screen width). The viewer reads it from the manifest, so C can tune it.
- **Bleed:** the visible frame is the middle 90%. Paint 5% extra on every side of every layer, because layers shift by up to that much.
- **Size:** each layer is **2048 × 1152 px** (16:9, bleed included), cut into **2 × 2 tiles of 1024 × 576**. Roblox shrinks any image above 1024 px on a side, so whole layers would come out blurry. Tiles run row by row from the top left.
- Transparent layers are PNG with clean, premultiplied-looking edges (no dark halos): smoke and glows fade to full transparency.
- Optional: keep the explosions and missile flames on their own `fx` layer (depth 0.6). The viewer can then flicker them gently. A pure nice-to-have.

## 3. Hand-off: the manifest

Uploads need the user's approval, as for meshes. Once uploaded, C adds a `keyArt` table to the mesh manifest (`src/shared/Defs/Meshes/Registry.luau`, C's generated file), next to `units` and `fx`:

```lua
keyArt = {
	dusk_battle = {
		status = "review", -- "approved" shows in the game; "review" only in Studio
		title = "Dusk battle",
		size = { 2048, 1152 },
		tiles = { 2, 2 }, -- columns, rows
		layers = { -- back to front
			{ name = "sky", depth = 0.08, images = { "rbxassetid://…", "rbxassetid://…", "rbxassetid://…", "rbxassetid://…" } },
			{ name = "far", depth = 0.3, images = { … } },
			{ name = "mid", depth = 0.6, images = { … } },
			{ name = "near", depth = 1.0, images = { … } },
		},
	},
},
```

Both loading screens read it through `@shared/Defs/Meshes/Registry`. Without approved art they keep what they draw today (the lobby: the live 3D battle; the match: its gradient).

## 4. The viewer (both screens behave the same)

- Covers the screen at 16:9, cropping the bleed (wider screens crop top and bottom; taller ones the sides).
- Each layer moves by `mouse (−1..1) × 2.5% of the width × depth`, eased (about 0.4 s). There's also a slow idle drift, so it moves on its own while you wait.
- The text bands (top title, bottom tip and bar) get a dark gradient for legibility.
- Images preload (`ContentProvider:PreloadAsync`); the art fades in once loaded and is never shown half-drawn.

## Changes

- 2026-10-23: first version (L-13).
- 2026-10-24: all three arts at dusk (the user's style guide); art 1 "Commander's stand" approved by the user, waiting for upload approval.
- 2026-10-23: one viewer, `src/client/UI/KeyArt.luau`; the lobby's copy is gone.
