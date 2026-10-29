// Strategic icon sprite sheet (C-74) from the user's icon set,
// docs/art/icons/ftgg-unit-icons.html (draft 4, BAR style: frame shape =
// unit type, dots under the frame = tech level, white symbol = weapon or
// role). Its FR, SYM, CAT and iconSVG are the source of truth and are run
// from the HTML itself; every tile is exported with its Copy SVG logic,
// iconSVG(it, "#ffffff", ...): white with a dark edge, so ImageColor3 tints
// it per team. Tiles: one per (catalogue entry, frame, tier) and one contact
// (dashed frame, no symbol or dots) per frame; ghosts are the unit tile at
// 45% opacity (ImageTransparency), as in the HTML. Every unit def maps to
// at most one entry: its id in the entry's `defs` (draft 4). Placeholder
// entries (`ph: 1`, no defs; draft 7, C-258) get a tile each, written as
// IconAtlas.placeholders by frame; a def in no entry is a warning, and the
// client draws its type's placeholder by the sheet's "Placeholder rule".
// A sheet whose pixels changed since its upload (assets.json `sha256`) loses
// its asset id, so a stale image is never shipped.
//
// Run from the project root: node tools/icons/render.mjs
// Writes assets/icons/ftgg-icons.png (then ftgg-icons-2.png ... once a sheet
// is full), src/client/UI/IconAtlas.luau (the sheets' asset ids from
// tools/icons/assets.json, `images`) and previews in debug_out/icons/.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { createHash } from "node:crypto";
import { Resvg } from "@resvg/resvg-js";

const HTML = "docs/art/icons/ftgg-unit-icons.html";
const SHEET = 1024; // Roblox's largest image size
const TW = 96; // tile width (the user's draft 4 size); the height follows the viewBox
const MAX_SHEETS = 4; // more is a mistake, not growth: fail
const sheetFile = (n) => (n === 1 ? "assets/icons/ftgg-icons.png" : `assets/icons/ftgg-icons-${n}.png`);
const VIEW_W = 48, VIEW_H = 56; // iconSVG's viewBox

// ---- the icon set, run from the HTML ----
const html = readFileSync(HTML, "utf8");
const from = html.indexOf("const DARK");
const to = html.indexOf("// ---- state ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: DARK / state markers not found`);
const { FR, CAT, scaleOf, iconSVG, TEAMS } = new Function(`${html.slice(from, to)}; return { FR, CAT, scaleOf, iconSVG, TEAMS };`)();

// ---- unit defs (from the registry, through Lune) ----
const defs = JSON.parse(execSync("lune run icon_defs", { encoding: "utf8" }));

// Every catalogue item lists its defs exactly (`defs`, draft 4): each unit
// def is in exactly one item, and nothing is guessed from names, families or
// icon keys. A def in no item, in two, or an id that is no def fails the run.
const items = CAT.flatMap((sec) => sec.items);
const defsOf = (it) => String(it.defs || "").split(/\s+/).filter(Boolean);

const problems = []; // fatal
const fallbacks = []; // { def, frame }: defs drawn with a placeholder
const mapping = []; // { def, item }
const itemOf = new Map();
for (const it of items) {
	if (!it.defs && !it.ph) problems.push(`catalogue "${it.n}" has no defs`);
	for (const id of defsOf(it)) {
		if (itemOf.has(id)) problems.push(`${id} is listed under "${itemOf.get(id).n}" and "${it.n}"`);
		else itemOf.set(id, it);
	}
}
// The sheet's "Placeholder rule": the frame whose placeholder a def with no
// entry gets (Core/Icons.placeholderFrame does the same in the client).
function placeholderFrame(def) {
	const mc = def.moveClass;
	if (def.domain === "structure") return def.armed ? "defense" : "struct";
	if (def.domain === "air") return mc === "HELI" ? "vtol" : "air";
	if (def.domain === "naval") return mc === "SUB" ? "sub" : "ship";
	if (mc === "WALKER" || mc === "AMPHIB_WALKER") return "walker";
	if (mc === "AMPHIB") return "amphib";
	if (mc === "HOVER") return "hover";
	return "vehicle";
}
const known = new Set(defs.map((d) => d.id));
for (const [id, it] of itemOf) if (!known.has(id)) problems.push(`catalogue "${it.n}" lists ${id}, which is no unit def`);
for (const def of defs) {
	const item = itemOf.get(def.id);
	if (!item) {
		fallbacks.push({ def, frame: placeholderFrame(def) });
		continue;
	}
	if (item.t !== def.tier) console.log(`note: ${def.id}: catalogue says T${item.t}, the def T${def.tier} (the catalogue's is drawn)`);
	mapping.push({ def, item });
}
if (problems.length > 0) {
	for (const p of problems) console.error(`PROBLEM: ${p}`);
	process.exit(1);
}

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
	// one tile per catalogue item: slug(name)_t<tier>
	const unit = tile(`${slug(m.item.n)}_t${m.item.t}`, m.item, "unit");
	byDef[m.def.id] = { tile: unit, scale: scaleOf(m.item), frame: m.item.f, name: m.item.n };
}
// placeholders: one per frame, used or not (a def added later falls back to one)
const placeholders = {};
for (const it of items) if (it.ph) placeholders[it.f] = tile(`${slug(it.n)}_t${it.t}`, it, "unit");
for (const fb of fallbacks) if (!placeholders[fb.frame]) problems.push(`${fb.def.id} is in no catalogue item, and the sheet has no placeholder for its frame ${fb.frame}`);
if (problems.length > 0) {
	for (const p of problems) console.error(`PROBLEM: ${p}`);
	process.exit(1);
}
const contacts = {};
for (const f of Object.keys(FR)) contacts[f] = tile(`contact_${f}`, { f }, "contact");

// Fixed-size tiles on 1024-px sheets; when one sheet is full the next one
// starts (C-183), and every tile carries its sheet's number.
const th = (w) => Math.round((w * VIEW_H) / VIEW_W);
const TH = th(TW), COLS = Math.floor(SHEET / TW), ROWS = Math.floor(SHEET / TH), PER_SHEET = COLS * ROWS;
// A stable layout: tiles keep the spot they had in the last IconAtlas.luau
// (same tile size), so new units or entries don't move the others and an
// uploaded sheet stays right until the next import; new tiles take free spots.
const previous = new Map();
const atlasPath = "src/client/UI/IconAtlas.luau";
if (existsSync(atlasPath)) {
	const old = readFileSync(atlasPath, "utf8");
	const size = old.match(/TILE_W = (\d+)/);
	if (size && +size[1] === TW) for (const m of old.matchAll(/^\t(\w+) = \{ (\d+), (\d+)(?:, (\d+))? \},\r?$/gm)) previous.set(m[1], [+m[2], +m[3], +(m[4] || 1)]);
}
const taken = new Set();
for (const t of tiles) {
	const p = previous.get(t.key);
	if (p && !taken.has(p.join())) ((t.x = p[0]), (t.y = p[1]), (t.sheet = p[2]), taken.add(p.join()));
}
const spot = (slot) => [(slot % COLS) * TW, Math.floor((slot % PER_SHEET) / COLS) * TH, Math.floor(slot / PER_SHEET) + 1];
let slot = 0;
for (const t of tiles) {
	if (t.x !== undefined) continue;
	while (taken.has(spot(slot).join())) slot++;
	const [x, y, sheet] = spot(slot);
	if (sheet > MAX_SHEETS) throw new Error(`${tiles.length} tiles need more than ${MAX_SHEETS} sheets of ${PER_SHEET} (${TW} x ${TH} px): check the catalogue`);
	((t.x = x), (t.y = y), (t.sheet = sheet));
	taken.add(spot(slot).join());
}
// never write past a sheet's edge
for (const t of tiles) {
	if (t.x < 0 || t.y < 0 || t.x + TW > SHEET || t.y + TH > SHEET) throw new Error(`tile ${t.key} at ${t.x}, ${t.y} runs off the ${SHEET}-px sheet ${t.sheet}`);
}
const SHEETS = Math.max(...tiles.map((t) => t.sheet));

// ---- the sheet: each tile is the Copy SVG export, placed on the grid ----
const place = (svg, x, y, w) => svg.replace(/^<svg /, `<svg x="${x}" y="${y}" `).replace(/width="\d+" height="\d+"/, `width="${w}" height="${th(w)}"`);
const sheetSvg = (bodies, w = SHEET, h = SHEET, bg = "") =>
	`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${bg}${bodies.join("")}</svg>`;
const render = (svg) => new Resvg(svg, { fitTo: { mode: "original" } }).render();
mkdirSync("assets/icons", { recursive: true });
const onSheet = (n) => tiles.filter((t) => t.sheet === n);
const whites = [];
const hashes = [];
for (let n = 1; n <= SHEETS; n++) {
	const white = render(sheetSvg(onSheet(n).map((t) => place(iconSVG(t.it, "#ffffff", TW, t.mode), t.x, t.y, TW))));
	writeFileSync(sheetFile(n), white.asPng());
	hashes.push(createHash("sha256").update(white.pixels).digest("hex"));
	whites.push(white);
}

// ---- check: the white tile tinted (Roblox multiplies) vs the HTML drawn in team color ----
// The dark edge gets tinted too (#101411 x team color), the one place they differ.
const teamColor = (TEAMS.find((t) => t.id === "order") || TEAMS[1]).color;
const tint = [1, 3, 5].map((i) => parseInt(teamColor.slice(i, i + 2), 16));
let worst = 0, sum = 0;
for (let n = 1; n <= SHEETS; n++) {
	const colored = render(sheetSvg(onSheet(n).map((t) => place(iconSVG(t.it, teamColor, TW, t.mode), t.x, t.y, TW)))).pixels;
	const wp = whites[n - 1].pixels; // premultiplied RGBA
	for (let i = 0; i < wp.length; i += 4) {
		const d = Math.max(Math.abs(wp[i + 3] - colored[i + 3]), ...[0, 1, 2].map((k) => Math.abs((wp[i + k] * tint[k]) / 255 - colored[i + k])));
		sum += d;
		worst = Math.max(worst, d);
	}
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
// assets.json: { images: [sheet 1's id, sheet 2's, ...], sha256: [each sheet's
// pixel hash when it was uploaded] } (the old { image } is sheet 1). An id
// whose sheet changed since, or that has no hash, is dropped: upload that
// sheet again, then record its id and the hash this run prints.
const uploaded = assets.images || (assets.image ? [assets.image] : []);
const ids = uploaded.map((id, i) => (assets.sha256 && assets.sha256[i] === hashes[i] ? id : ""));
const stale = uploaded.map((id, i) => (id && !ids[i] ? i + 1 : 0)).filter(Boolean);
const q = (s) => JSON.stringify(s);
const L = [];
L.push("--!strict");
L.push("-- GENERATED by tools/icons/render.mjs from docs/art/icons/ftgg-unit-icons.html");
L.push("-- (C-74); don't edit. The strategic icon sprite sheet: every icon white with a");
L.push("-- dark edge, tinted per team by ImageColor3; ghosts are the unit tile at 45%");
L.push("-- opacity. The sheets' asset ids come from tools/icons/assets.json (\"\" until uploaded).");
L.push("");
L.push("local IconAtlas = {}");
L.push("");
L.push("export type Entry = { tile: string, scale: number, frame: string, name: string }");
L.push("");
L.push("-- one image per sheet; a tile's third number is its sheet");
L.push("IconAtlas.images = {");
for (let n = 1; n <= SHEETS; n++) L.push(`\t${q(asset(ids[n - 1]))},`);
L.push("} :: { string }");
L.push(`IconAtlas.TILE_W = ${TW} -- pixels per icon on the sheet`);
L.push(`IconAtlas.TILE_H = ${TH}`);
L.push(`IconAtlas.GHOST_TRANSPARENCY = 0.55`);
L.push("");
L.push("-- tile key → its top-left pixel and its sheet: { x, y, sheet }");
L.push("IconAtlas.tiles = {");
for (const t of tiles) L.push(`\t${t.key} = { ${t.x}, ${t.y}, ${t.sheet} },`);
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
L.push("-- a unit def in no catalogue item draws its type's placeholder, by frame (the");
L.push("-- sheet's \"Placeholder rule\", Core/Icons.placeholderFrame)");
L.push("IconAtlas.placeholders = {");
for (const [f, k] of Object.entries(placeholders)) L.push(`\t${f} = ${q(k)},`);
L.push("} :: { [string]: string }");
L.push("");
L.push("-- radar / sonar contacts: the dashed frame with no symbol or dots, by frame");
L.push("IconAtlas.contacts = {");
for (const [f, k] of Object.entries(contacts)) L.push(`\t${f} = ${q(k)},`);
L.push("} :: { [string]: string }");
L.push("");
L.push("return IconAtlas");
writeFileSync("src/client/UI/IconAtlas.luau", L.join("\n") + "\n");

// ---- report ----
console.log(`${defs.length} unit defs → ${mapping.length} mapped from ${items.length} catalogue items' defs`);
console.log(`${tiles.length} tiles of ${TW} x ${TH} px on ${SHEETS} sheet(s) of ${PER_SHEET} (${COLS} x ${ROWS}): ${tiles.filter((t) => t.mode === "unit").length} unit (${Object.keys(placeholders).length} placeholders), ${tiles.filter((t) => t.mode === "contact").length} contact`);
for (const fb of fallbacks) console.log(`WARNING: ${fb.def.id} (${fb.def.name}) is in no catalogue item: drawn with placeholder_${fb.frame}`);
for (const n of stale) console.log(`WARNING: sheet ${n} changed since its upload: its asset id is dropped until it's uploaded again`);
console.log(`white tinted vs the HTML in ${teamColor}: worst pixel ${worst.toFixed(1)} / 255, mean ${(sum / (SHEETS * SHEET * SHEET)).toFixed(3)} (dark edges get tinted)`);
for (let n = 1; n <= SHEETS; n++) console.log(`sheet ${n}: ${sheetFile(n)}, ${onSheet(n).length} tiles, sha256 ${hashes[n - 1]}, asset id ${ids[n - 1] || "(none: upload it, then add its id and this sha256 to tools/icons/assets.json)"}`);
for (const it of items) if (!it.ph && !mapping.some((m) => m.item === it)) console.log(`note: catalogue "${it.n}" is used by no def`);
