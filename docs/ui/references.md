# UI style references (BAR)

The user shared BAR screenshots as **style** references (2026-10-23). Build our own versions with the UI kit (`src/client/UI/Kit.luau`, C-105). Don't copy textures, icons or font files. The images live in the chat, not in the repo; these are the points to follow.

## 1. Multiplayer match lobby

- **Top navigation:** big upper-case tabs (Singleplayer / Multiplayer / Library / Development), the chosen one on a lighter block. Small sub-tabs underneath (Ranked, Casual, Custom). On the right: icon buttons, players online with a green dot, the user name.
- **Header:** the room title (e.g. "EU - 2 13 | Teams 8 vs 8"), "Hosted by …", and "Running for 3 minutes" on the right.
- **Teams:** each team is a heading ("Team 1", with "(8 Members)" dimmer) with small "Add bot" and "Join" buttons. Under it, players as chips in a wrapping row: flag, name, and a red or green ready dot. A thin divider separates teams; spectators are a last section the same way.
- **Middle:** chat, with each message on a translucent teal-grey bar; an input box under it.
- **Right column:**
  - the map preview;
  - segmented "Start Pos / Fixed / Boxes" with small layout icons;
  - setting rows as a darker **label cell** joined to a **value cell** with a chevron (Map, Game, Engine, Preset, Balance Mode, Team Size with a stepper, Num of Teams), and icon buttons (list, gear) beside them.
- **Actions** at the bottom right: **Leave** (dark red), **Join Queue** and **Watch** (green), all full-height blocks.

## 2. Single-player scenarios menu

- **Title:** a large, light "Scenarios".
- **Grid:** 3 columns of image cards, **greyscale** with the name in white at the bottom left over a dark fade. The selected or hovered card is **in color** with a light outline.
- **Detail pane on the right:**
  - title, description paragraphs (small), then label / value rows ("Victory condition", "Lose condition");
  - Faction and Difficulty rows: label cell plus dropdown, full width;
  - a full-width **green Launch** button.

## 3. In-game HUD at start

- **Resources:** two bars at the top centre, each with an icon, −/+ income, the big stored number, a fill bar with a share marker, and a small red tag ("Wasting metal") on the corner. A small speed / multiplier box beside them.
- **Top right:** a flat text menu (Save, Statistics, Changes, Keys, Settings, Lobby).
- **Minimap** at the top left, with the camera trapezoid; tiny buttons under it.
- **Build grid** at the bottom left:
  - 4 × 3 **unit pictures** (rendered model portraits), with cost numbers stacked at the bottom right (white metal, yellow energy) and a small type icon at the bottom left;
  - category tabs with hotkeys under the grid: "Economy Z", "Combat X", "Utility C", "Build V", each with a coloured icon.
- **Selected unit panel:** a portrait with health over it (e.g. 2 700 / 26 000), the name in **yellow-green**, the role under it, and compact stats on wrapped lines ("DPS …, Range …, Reload …"). Income lines (+1.0, +15) and a green heart with HP sit on the far left.
- **Command grid:** small dark buttons in 5 columns ("Fire at will", "Hold pos", "Repeat Off", "High Priority", "Visible", …). State buttons have a short **coloured underline** (green on, red off).
- **Bottom right:** game time, speed ×, fps, clock; the music line; the player list (allies, then "Enemies" in red).
- **Messages** in the middle top ("[Initial Spawn] …", "… paused the game"); "GAME PAUSED" in big faint letters.

## 4–5. Settings panels

- **Header:** "Settings" at the top left, a **search box** across the top, and toggles at the top right: "Unfold all", "Advanced".
- **Sidebar:** sections (Graphics, Interface, Game, Control, Audio, Notifications, Accessibility). The chosen section has a lighter pill, and its **sub-sections** are listed under it, the active one marked by a short **amber bar** on its left.
- **Content:**
  - section headers in **amber** on a slightly lighter band, with a thin amber underline;
  - rows indented by level: a parent row has a ▾ fold arrow, and its children are indented and dimmer when the parent is off;
  - controls are right-aligned: dark dropdown boxes with a small ▾, sliders with a **square knob** and the value on the right, small toggles (square knob, green on, red off).
- **Footer:** the hovered option's name and its help text, plus a faint "/option name" hint at the bottom right.

## 6. Selecting, building preview, radar range

- **Radar range:** a translucent **green fill** with concentric lighter rings, cut by terrain (line-of-sight shaped, blocky edges), mirrored on the minimap.
- **Placement:** a fine light **grid** around the placement point.
- **Selected unit:** red and green circles (weapon and other ranges) round it; build-option spots shown as small faint swirl markers.

## 7. Factory spawn direction

- **Ghost:** the placement ghost is green, with a small **arrow on its exit side** showing which way it faces.
- **Message:** "Buildings set to face East".
- **Around it:** the grid and the build range circles.

## What our kit already matches, and what's still to do

- **Matches:**
  - dark translucent panels with a stripe, light text, amber accent, sidebar with a pill;
  - green / red toggles, sliders with values, segmented and dropdown controls, chips with team swatches, the statistics grid of small line charts.
- **To do, when we get there:**
  - settings: search box, sub-sections with the amber bar, amber section headers with an underline, fold arrows and indented child rows, the help footer, square slider knobs;
  - lobby: player chips with ready dots, label-cell + value-cell rows, coloured Leave / Join / Watch blocks, the map preview;
  - a scenarios-style card grid (greyscale, color on select);
  - HUD: cost numbers on build tiles, hotkey tabs, coloured underlines on command state buttons, a yellow-green unit name, the top-right text menu;
  - in-world: a terrain-cut radar range fill with rings, the factory facing arrow and "face East" message.
