# Sound plan (client, 2026-10-22)

Not implemented and nothing inserted: a list of the sounds the game needs, what plays each one, and candidate Roblox Creator Store audio IDs for the user to choose from (searched in Studio's Creator Store, free audio).

**Licensing.** Prefer **ProSoundEffects** entries: Roblox licensed that library for free use in experiences (their names end in "(SFX)"). Community uploads have an unknown licence; several are clearly ripped from other games or videos. Those are marked **don't use**, listed only so nobody picks them by accident. Play every candidate before choosing: the store search is fuzzy and some results are unrelated.

**How sounds would hook in.** Weapons already name their sound in the defs (`fx.sound`, keys below), and the client knows every shot, impact, launch and death (Core/Effects). Unit loops (engines, rotors) would follow the drawn models; UI and alerts follow the client API's signals. A sound module would map keys to asset IDs in one table, with pooled `Sound` instances, a cap on how many play at once, and distance falloff from the camera.

## Weapons (the defs' `fx.sound`)

| Key (defs using it) | Need | Candidates |
|---|---|---|
| `cannon_light` (Order T1 tank gun), `cannon_heavy` (×6: heavy tanks, turrets, Juggernaut) | a tank gun crack, heavy variant pitched down | 131068121289461 "Tank Cannon Fire" (NickySergal, community); 2721745637 "Tank Cannon - Fire from Interior" (NS_Shard, community; muffled, for close-ups); 98794411250992 "Tank Cannon Interior Fire 02" (community); 136123485437968 "tank fire" (community). **Don't use:** 82423517276497 "BF1 Tank Fire Outside" (credits DICE). |
| `howitzer`, `mortar` (artillery, fortress guns) | a deep boom with a tail | 9114840880 "Howitzer Shell Eject 2 (SFX)" (ProSoundEffects, 10.9 s: fire, eject, distant hits; trim); 9113169264 "Artillery Distant 1 (SFX)" (ProSoundEffects, distant booms, also for ambience) |
| `mlrs`, `rockets` | a salvo of rocket whooshes | 717392973 "Missile Launch (Kibblesbob Launch)" (community, "free to use"); 79387335575828 "Missile_launch" (community) |
| `sam_ir`, `sam_radar`, `aam` | a missile launch: ignition plus whoosh; radar SAMs heavier | 139127658858339 "missile launch" (community); 85234809708426 "Missile Launch" (community); 76270470644551 "missile_rocket_loop" (community; a flight loop for long radar shots) |
| `mg` | machine-gun bursts | 9116358625 "Machine Gun Bursts 5 (SFX)" (ProSoundEffects, 4.6 s); 9116358349 "Machine Gun Bursts 4 (SFX)" (ProSoundEffects). **Don't use:** 123394057778403 "Metal Slug Machine Gun Burst Fire". |
| `flak` | rapid AA cannon thumps | 105314782480916 "Auto cannon shot 2" (community) |
| `naval_gun`, `naval_gun_heavy` | ship guns (the cannon sounds pitched down, plus a water slap) | as `cannon_heavy`, layered with the splash below |
| `torpedo` | a launch splash, then an underwater run | 9118908452 "Septic Plumbing Bubbles Sucks Heavy 4 (SFX)" (ProSoundEffects; bubbles, usable for the underwater run); nothing good found for the launch: search "torpedo" with the user |
| `bomb`, `bomb_heavy` | a falling whistle, then the explosion | 116150406781332 "Falling whistle sound effect" (community) |
| `nuke_launch` | a heavy launch roar | as the radar SAMs pitched far down, or search "rocket launch" with the user |
| `demolition` (Minotaur) | a sharp demolition charge | the explosions below, short and dry |

## Impacts and deaths

| Event | Need | Candidates |
|---|---|---|
| impact, small / medium | explosions by size | 138533090376585 "Explosion Blast Impact Boom" (community, tagged sfx); 140278004623742 "explosion" (community) |
| impact large, death | big fiery explosions | 126462172690929 / 107882121969514 / 139900006476219 "Large fire explosion" 1–3 (oatmeeaI, community; a matching set) |
| nuke detonation | a huge, long explosion and rumble | 7163539309 "Nuclear Explosion" (community); 6507875778 "Nuclear Explosion" (community, 7 s); 79596254161483 "Huge Nuclear Explosion" (community) |
| splash (C-82) | shells and bombs into water | 9125703162 "Mud Puddle Splash Shallow Water Impacts Hits (SFX)" (ProSoundEffects, 1.1 s; pitched down for shells); 126105529228330 "water splash" (community) |
| hit on a unit | a metallic clank under the explosion | search "metal impact SFX" |
| **Don't use** | | 139810215781954 "ultrakill-bigger-explosion", 139771888058836 "Meme Explosion" |

## Units

| Need | Candidates |
|---|---|
| tank engine and tracks (a loop by speed) | 9112769003 / 9112768824 "Diesel Train 1–2 (SFX)" (ProSoundEffects: rumble and track clatter; filtered, a stand-in until a real tank loop is found) |
| jet pass-by | 9114888034 / 9114888141 "Jet Pass By 1–2 (SFX)" (ProSoundEffects, 2.5 s); 8099845651 "Jet Fly By" (community). **Don't use:** 6325117414 (a ZapSplat file re-uploaded). |
| helicopter rotor loop | 126966962086051 "Helicopter Rotors" (community); 99103708154004 "Helicopter sound" (community) |
| ship horn / engine | 113335743695644 "ship horn sound effect" (community); 111837497430607 "Cruise Ship Horn" (community). **Don't use:** 104145730265395 (taken from a YouTube video, says so). |
| construction / factory work | 9112840131 "Oil Refinery Ambience 3 (SFX)" (ProSoundEffects, a machine hum loop, quiet under a factory) |

## Alerts and UI

| Need | Candidates |
|---|---|
| nuclear launch detected | 9113073796 "Air Raid Siren Old Fashioned 2 (SFX)" (ProSoundEffects, 29.8 s; play the first rise); 6466025566 "Nuclear missile alarm" (community) |
| unit / structure under attack, lost | a short alert tone: search "alert beep SFX" (none chosen yet) |
| missile lock (the missile view) | 14682171992 "Missile Target Locked On" (community) |
| button click | 88442833509532 "ui-simple-button-click" (AmbientSorcery, community); 119393948345399 "UI Modern Button Click" (community). **Don't use:** 9065073444 "Darkest Dungeon SFX". |
| order given, build placed, selection | short clicks and blips (same family as the button click) |
| victory / defeat stingers | not searched yet |

## Ambience

| Need | Candidates |
|---|---|
| distant battle bed under the fight | 9112892993 / 9112893131 / 9112893134 "Warfare Composite 601–603 (SFX)" (ProSoundEffects, 65–73 s loops: guns, explosions, aircraft; WWI-era but fits low in the mix); 9113169264 "Artillery Distant 1 (SFX)" |
| wind, sea | not searched yet (ProSoundEffects has both) |

Listed under "Needs my review" in `docs/progress/client.md`.
