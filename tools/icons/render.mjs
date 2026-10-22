// Strategic icon sprite sheet (C-74) from the user's icon set,
// docs/art/icons/ftgg-unit-icons.html (draft 2, BAR style: frame shape =
// unit type, dots under the frame = tech level, white symbol = weapon or
// role). Its FR, SYM, CAT and iconSVG are the source of truth and are run
// from the HTML itself; every tile is exported with its Copy SVG logic,
// iconSVG(it, "#ffffff", ...): white with a dark edge, so ImageColor3 tints
// it per team. Tiles: one per (catalogue entry, frame, tier) and one contact
// (dashed frame, no symbol or dots) per frame; ghosts are the unit tile at
// 45% opacity (ImageTransparency), as in the HTML. Every unit def must map
// to an entry (its id in the entry's ids, else its icon family below).
//
// Run from the project root: node tools/icons/render.mjs
// Writes assets/icons/ftgg-icons.png, src/client/UI/IconAtlas.luau (asset id
// from tools/icons/assets.json) and previews in debug_out/icons/.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { Resvg } from "@resvg/resvg-js";

const HTML = "docs/art/icons/ftgg-unit-icons.html";
const SHEET = 1024; // Roblox's largest image size
const VIEW_W = 48, VIEW_H = 56; // iconSVG's viewBox

// ---- the icon set, run from the HTML ----
const html = readFileSync(HTML, "utf8");
const from = html.indexOf("const DARK");
const to = html.indexOf("// ---- state ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: DARK / state markers not found`);
const { FR, CAT, scaleOf, iconSVG, TEAMS } = new Function(`${html.slice(from, to)}; return { FR, CAT, scaleOf, iconSVG, TEAMS };`)();

// ---- unit defs (from the registry, through Lune) ----
const defs = JSON.parse(execSync("lune run icon_defs", { encoding: "utf8" }));

// Icon families whose defs the catalogue names by kind rather than by id
// (structures shared by both factions), by domain.
const FAMILY = {
	"structure:factory": "Vehicle Plant",
	"structure:factory_air": "Airfield",
	"structure:factory_naval": "Shipyard",
	"structure:extractor": "Supply Extractor",
	"structure:generator": "Power Generator",
	"structure:solar": "Power Generator",
	"structure:wind": "Power Generator",
	"structure:tidal": "Tidal Generator",
	"structure:fusion": "Fusion Reactor",
	"structure:storage": "Storage",
	"structure:radar": "Radar Tower",
	"structure:jammer": "Jammer Tower",
	"structure:sonar": "Sonar Station",
	"structure:converter": "Supply Converter",
	"structure:airpad": "Rearm Pad",
	"structure:pinpointer": "Pinpointer",
};

// Defs the catalogue doesn't have yet, drawn with an existing entry until it
// does (reported on every run): new units that would otherwise need a new
// sheet and a re-import.
const STOPGAP = {
	ord_warden: "Main Battle Tank", // S-64: a deployable gun
	chs_minotaur: "Main Battle Tank", // S-64: a siege ram
	chs_locust: "Light Tank", // S-75: a cheap autocannon tank
	chs_cyclops: "Artillery", // S-75: a siege mortar (structures only)
	ord_barrier: "Storage", // S-75: a wall segment, no weapon
	ord_citadel: "Heavy Turret", // S-75: a fortress gun with a SAM and a radar
	ord_phalanx: "Jammer Tower", // S-79: a shield dome generator
	chs_carapace: "Jammer Tower", // S-79: a shield dome generator
	ord_radiance: "Heavy Turret", // S-96: a long-range beam tower
	chs_inferno: "Heavy Turret", // S-96: a long-range beam tower
	ord_lumen: "IR SAM Site", // S-96: a flak tower (anti-air)
	chs_hailstorm: "IR SAM Site", // S-96: a flak tower (anti-air)
	ord_sanction: "Artillery Emplacement", // S-110: a T2 missile battery
	chs_scourge: "Artillery Emplacement", // S-110: a T2 missile battery
	chs_wraith: "Strategic Bomber", // S-109: a decoy heavy bomber
	ord_providence: "Radar SAM Site", // S-111: an anti-nuke (family "antinuke")
	chs_cerberus: "Radar SAM Site", // S-111: an anti-nuke
	ord_custodian: "Mobile Radar SAM", // S-111: a mobile anti-nuke
	chs_chimera: "Mobile Radar SAM", // S-111: a mobile anti-nuke
};

// Entries drawn in the frame of each def's own domain rather than the
// catalogue's (the user: Pinpointers use their actual domain's frame).
const OWN_FRAME = new Set(["Pinpointer"]);
const DOMAIN_FRAME = { ground: "vehicle", air: "air", naval: "ship", structure: "struct" };

const items = CAT.flatMap((sec) => sec.items);
const byName = new Map(items.map((it) => [it.n, it]));
const idsOf = (it) => new Set(String(it.ids).match(/\b(?:ord|chs|neu)_[a-z0-9_]+/g) || []);

const problems = [];
const mapping = []; // { def, item, tier, how }
for (const def of defs) {
	const explicit = items.filter((it) => idsOf(it).has(def.id));
	let item = explicit[0], how = "id";
	if (explicit.length > 1) problems.push(`${def.id} is listed under ${explicit.map((i) => i.n).join(" and ")}`);
	if (!item) {
		item = byName.get(FAMILY[`${def.domain}:${def.family}`]);
		how = "family";
	}
	if (!item && STOPGAP[def.id]) {
		item = byName.get(STOPGAP[def.id]);
		how = "stopgap";
		problems.push(`${def.id} (${def.name}) has no catalogue entry yet: drawn as "${STOPGAP[def.id]}"`);
	}
	if (!item) {
		problems.push(`${def.id} (${def.name}, ${def.domain} ${def.family}, T${def.tier}) fits no catalogue entry`);
		continue;
	}
	// the catalogue's tier for named defs; a family entry covers T1 and T2 variants
	const tier = how === "family" ? def.tier : item.t;
	if (how === "id" && item.t !== def.tier) problems.push(`${def.id}: catalogue says T${item.t}, the def T${def.tier} (the catalogue's is drawn)`);
	mapping.push({ def, item, tier, how });
}
// catalogue ids that are no def (typos, renamed or removed units), entries nothing uses
const known = new Set(defs.map((d) => d.id));
for (const it of items) for (const id of idsOf(it)) if (!known.has(id)) problems.push(`catalogue "${it.n}" lists ${id}, which is no unit def`);
for (const it of items) if (!mapping.some((m) => m.item === it)) problems.push(`catalogue "${it.n}" is used by no def`);

// ---- tiles ----
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
const tiles = []; // { key, it, mode }
const tileOf = new Map();
function tile(key, it, mode) {
	if (!tileOf.has(key)) {
		tileOf.set(key, tiles.length);
		tiles.push({ key, it, mode });
	}
	return key;
}
const byDef = {};
for (const m of mapping) {
	const f = OWN_FRAME.has(m.item.n) ? DOMAIN_FRAME[m.def.domain] : m.item.f;
	const it = { ...m.item, f, t: m.tier };
	const tag = f === m.item.f ? "" : `_${f}`;
	const unit = tile(`${slug(m.item.n)}${tag}_t${m.tier}`, it, "unit");
	byDef[m.def.id] = { tile: unit, scale: scaleOf(m.item), frame: f, name: m.item.n };
}
const contacts = {};
for (const f of Object.keys(FR)) contacts[f] = tile(`contact_${f}`, { f }, "contact");

// the largest tile (at the viewBox's aspect) that fits every icon on one sheet
let TW = 128;
const th = (w) => Math.round((w * VIEW_H) / VIEW_W);
while (Math.floor(SHEET / TW) * Math.floor(SHEET / th(TW)) < tiles.length) TW -= 4;
const TH = th(TW), COLS = Math.floor(SHEET / TW), ROWS = Math.floor(SHEET / TH);
// A stable layout: tiles keep the spot they had in the last IconAtlas.luau
// (same tile size), so new units or entries don't move the others and an
// uploaded sheet stays right until the next import; new tiles take free spots.
const previous = new Map();
const atlasPath = "src/client/UI/IconAtlas.luau";
if (existsSync(atlasPath)) {
	const old = readFileSync(atlasPath, "utf8");
	const size = old.match(/TILE_W = (\d+)/);
	if (size && +size[1] === TW) for (const m of old.matchAll(/^\t(\w+) = \{ (\d+), (\d+) \},\r?$/gm)) previous.set(m[1], [+m[2], +m[3]]);
}
const taken = new Set();
for (const t of tiles) {
	const p = previous.get(t.key);
	if (p && !taken.has(p.join())) ((t.x = p[0]), (t.y = p[1]), taken.add(p.join()));
}
let slot = 0;
for (const t of tiles) {
	if (t.x !== undefined) continue;
	while (taken.has([(slot % COLS) * TW, Math.floor(slot / COLS) * TH].join())) slot++;
	if (Math.floor(slot / COLS) >= ROWS) throw new Error("the sheet is full");
	((t.x = (slot % COLS) * TW), (t.y = Math.floor(slot / COLS) * TH));
	taken.add([t.x, t.y].join());
}

// ---- the sheet: each tile is the Copy SVG export, placed on the grid ----
const place = (svg, x, y, w) => svg.replace(/^<svg /, `<svg x="${x}" y="${y}" `).replace(/width="\d+" height="\d+"/, `width="${w}" height="${th(w)}"`);
const sheetSvg = (bodies, w = SHEET, h = SHEET, bg = "") =>
	`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${bg}${bodies.join("")}</svg>`;
const render = (svg) => new Resvg(svg, { fitTo: { mode: "original" } }).render();
const white = render(sheetSvg(tiles.map((t) => place(iconSVG(t.it, "#ffffff", TW, t.mode), t.x, t.y, TW))));
mkdirSync("assets/icons", { recursive: true });
writeFileSync("assets/icons/ftgg-icons.png", white.asPng());

// ---- check: the white tile tinted (Roblox multiplies) vs the HTML drawn in team color ----
// The dark edge gets tinted too (#101411 x team color), the one place they differ.
const teamColor = (TEAMS.find((t) => t.id === "order") || TEAMS[1]).color;
const tint = [1, 3, 5].map((i) => parseInt(teamColor.slice(i, i + 2), 16));
const colored = render(sheetSvg(tiles.map((t) => place(iconSVG(t.it, teamColor, TW, t.mode), t.x, t.y, TW)))).pixels;
const wp = white.pixels; // premultiplied RGBA
let worst = 0, sum = 0;
for (let i = 0; i < wp.length; i += 4) {
	const d = Math.max(Math.abs(wp[i + 3] - colored[i + 3]), ...[0, 1, 2].map((k) => Math.abs((wp[i + k] * tint[k]) / 255 - colored[i + k])));
	sum += d;
	worst = Math.max(worst, d);
}

// ---- previews: every tile in two team colors, unit and ghost, on grass and sand ----
mkdirSync("debug_out/icons", { recursive: true });
const teams = ["order", "chaos"].map((id) => (TEAMS.find((t) => t.id === id) || TEAMS[1]).color);
for (const [name, bg] of Object.entries({ grass: "#456f38", sand: "#bba878" })) {
	const P = 40, cols = 12, rows = Math.ceil(tiles.length / cols) * 2;
	const body = [];
	tiles.forEach((t, i) => {
		const sc = t.mode === "unit" ? scaleOf(t.it) : 1;
		teams.forEach((c, k) => {
			const s = Math.round(22 * sc);
			const x = (i % cols) * P * 2 + k * P + (P - s) / 2, y = Math.floor(i / cols) * P * 2 + (P - th(s)) / 2;
			body.push(place(iconSVG(t.it, c, s, t.mode), x, y, s));
			if (t.mode === "unit") body.push(place(iconSVG(t.it, c, s, "ghost"), x, y + P, s));
		});
	});
	writeFileSync(`debug_out/icons/preview-${name}.png`, render(sheetSvg(body, cols * P * 2, rows * P, `<rect width="100%" height="100%" fill="${bg}"/>`)).asPng());
}

// ---- IconAtlas.luau ----
const assets = existsSync("tools/icons/assets.json") ? JSON.parse(readFileSync("tools/icons/assets.json", "utf8")) : {};
const asset = (id) => (id ? `rbxassetid://${String(id).replace(/\D/g, "")}` : "");
const q = (s) => JSON.stringify(s);
const L = [];
L.push("--!strict");
L.push("-- GENERATED by tools/icons/render.mjs from docs/art/icons/ftgg-unit-icons.html");
L.push("-- (C-74); don't edit. The strategic icon sprite sheet: every icon white with a");
L.push("-- dark edge, tinted per team by ImageColor3; ghosts are the unit tile at 45%");
L.push("-- opacity. The asset id comes from tools/icons/assets.json (\"\" until uploaded).");
L.push("");
L.push("local IconAtlas = {}");
L.push("");
L.push("export type Entry = { tile: string, scale: number, frame: string, name: string }");
L.push("");
L.push(`IconAtlas.image = ${q(asset(assets.image))}`);
L.push(`IconAtlas.TILE_W = ${TW} -- pixels per icon on the sheet`);
L.push(`IconAtlas.TILE_H = ${TH}`);
L.push(`IconAtlas.GHOST_TRANSPARENCY = 0.55`);
L.push("");
L.push("-- tile key → its top-left pixel");
L.push("IconAtlas.tiles = {");
for (const t of tiles) L.push(`\t${t.key} = { ${t.x}, ${t.y} },`);
L.push("} :: { [string]: { number } }");
L.push("");
L.push("-- unit def id → its icon: tile, size scale (tier), frame, catalogue name");
L.push("IconAtlas.byDef = {");
for (const d of defs) {
	const e = byDef[d.id];
	if (e) L.push(`\t${d.id} = { tile = ${q(e.tile)}, scale = ${e.scale}, frame = ${q(e.frame)}, name = ${q(e.name)} },`);
}
L.push("} :: { [string]: Entry }");
L.push("");
L.push("-- radar / sonar contacts: the dashed frame with no symbol or dots, by frame");
L.push("IconAtlas.contacts = {");
for (const [f, k] of Object.entries(contacts)) L.push(`\t${f} = ${q(k)},`);
L.push("} :: { [string]: string }");
L.push("");
L.push("return IconAtlas");
writeFileSync("src/client/UI/IconAtlas.luau", L.join("\n") + "\n");

// ---- report ----
console.log(`${defs.length} unit defs → ${mapping.length} mapped (${mapping.filter((m) => m.how === "family").length} by family), ${items.length} catalogue entries`);
console.log(`${tiles.length} tiles of ${TW} x ${TH} px (${COLS} per row on a ${SHEET} px sheet): ${tiles.filter((t) => t.mode === "unit").length} unit, ${tiles.filter((t) => t.mode === "contact").length} contact`);
console.log(`white tinted vs the HTML in ${teamColor}: worst pixel ${worst.toFixed(1)} / 255, mean ${(sum / (SHEET * SHEET)).toFixed(3)} (dark edges get tinted)`);
console.log(`asset id: ${assets.image || "(none)"}`);
for (const p of problems) console.log(`PROBLEM: ${p}`);
if (mapping.length < defs.length) process.exit(1);
