// Strategic icon sprite sheets (C-74) from the user's icon set,
// docs/art/icons/ftgg-unit-icons.html: its FRAMES, glyphs (G, sub),
// chevrons and catalogue (CAT) are the source of truth and are run from the
// HTML itself. Each icon is drawn in two layers on the same tile of two
// sheets:
//   fill    white, tinted with the team color by ImageColor3: the frame fill
//           (unit), the dashed frame (radar / sonar contact), the faded fill
//           and dashed frame (ghost);
//   overlay untinted, drawn over the fill: the dark outline (kept outside
//           the fill), the white frame stroke, the symbol and the chevrons.
// Tinted fill under the overlay gives back the HTML's icon; the script checks
// that on every tile. Units get one tile per (catalogue entry, tier), ghosts
// one per entry, contacts one per frame. Every unit def must map to an entry
// (its id in the entry's ids, else its icon family below).
//
// Run from the project root: node tools/icons/render.mjs
// Writes assets/icons/ftgg-icons-fill.png, assets/icons/ftgg-icons-overlay.png,
// src/client/UI/IconAtlas.luau (asset ids from tools/icons/assets.json) and
// previews in debug_out/icons/.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { Resvg } from "@resvg/resvg-js";

const HTML = "docs/art/icons/ftgg-unit-icons.html";
const SHEET = 1024; // Roblox's largest image size

// ---- the icon set, run from the HTML ----
const html = readFileSync(HTML, "utf8");
const from = html.indexOf("// ---- frames");
const to = html.indexOf("// ---- state ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: frames / state markers not found`);
const set = new Function(`${html.slice(from, to)}; return { FRAMES, G, sub, CAT, SCALE, chevrons, iconSVG };`)();
const { FRAMES, G, sub, CAT, SCALE, chevrons, iconSVG } = set;
const TEAM_COLORS = (() => {
	const m = html.match(/const TEAMS = (\[[\s\S]*?\]);/);
	return m ? new Function(`return ${m[1]}`)().map((t) => t.color) : ["#3f7fd6", "#d24a37"];
})();

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

// Entries drawn in the frame of each def's own domain (the user: Pinpointers
// use their actual domain's frame) rather than the catalogue's.
const OWN_FRAME = new Set(["Pinpointer"]);
const DOMAIN_FRAME = { ground: "ground", air: "air", naval: "naval", structure: "struct" };

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
	if (!item) {
		problems.push(`${def.id} (${def.name}, ${def.domain} ${def.family}, T${def.tier}) fits no catalogue entry`);
		continue;
	}
	// the catalogue's tier for named defs; a family entry covers T1 and T2 variants
	const tier = how === "id" ? item.t : def.tier;
	if (how === "id" && item.t !== def.tier && !(item.t === 0 && def.tier === 0)) {
		problems.push(`${def.id}: catalogue says T${item.t}, the def T${def.tier} (the catalogue's is drawn)`);
	}
	mapping.push({ def, item, tier, how });
}
// catalogue ids that are no def (typos, renamed or removed units)
const known = new Set(defs.map((d) => d.id));
for (const it of items) for (const id of idsOf(it)) if (!known.has(id)) problems.push(`catalogue "${it.n}" lists ${id}, which is no unit def`);
const unused = items.filter((it) => !mapping.some((m) => m.item === it));
for (const it of unused) problems.push(`catalogue "${it.n}" is used by no def`);

// ---- tiles ----
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
const tiles = []; // { key, item?, tier?, mode, frame }
const tileOf = new Map();
function tile(key, t) {
	if (!tileOf.has(key)) {
		tileOf.set(key, tiles.length);
		tiles.push({ key, ...t });
	}
	return key;
}
const byDef = {};
for (const m of mapping) {
	const f = OWN_FRAME.has(m.item.n) ? DOMAIN_FRAME[m.def.domain] : m.item.f;
	const item = { ...m.item, f };
	const tag = f === m.item.f ? "" : `_${f}`;
	const unit = tile(`${slug(m.item.n)}${tag}_t${m.tier}`, { item, tier: m.tier, mode: "unit", frame: f });
	const ghost = tile(`ghost_${slug(m.item.n)}${tag}`, { item, tier: m.tier, mode: "ghost", frame: f });
	byDef[m.def.id] = { unit, ghost, scale: m.item.big || SCALE[m.tier] || 1, frame: f, name: m.item.n };
}
const blips = {};
for (const f of Object.keys(FRAMES)) blips[f] = tile(`blip_${f}`, { mode: "blip", frame: f });

// the largest tile that fits every icon on one sheet
let TILE = 128;
while (Math.floor(SHEET / TILE) ** 2 < tiles.length) TILE -= 4;
const COLS = Math.floor(SHEET / TILE);
tiles.forEach((t, i) => ((t.x = (i % COLS) * TILE), (t.y = Math.floor(i / COLS) * TILE)));

// ---- the two layers of one icon (48 x 52 viewBox, as iconSVG) ----
const DARK = "#0e130f";
function layers(t, n) {
	const fr = FRAMES[t.frame];
	const [cx, cy] = fr.c;
	const glyph = t.item && t.item.g ? G[t.item.g](cx, cy, t.item.sg ? sub[t.item.sg] : null) : "";
	const mask = (id, black) => `<mask id="${id}" maskUnits="userSpaceOnUse" x="-10" y="-10" width="68" height="68"><rect x="-10" y="-10" width="68" height="68" fill="#fff"/>${black}</mask>`;
	if (t.mode === "unit") {
		return {
			fill: `<path d="${fr.d}" fill="#fff"/>`,
			overlay:
				mask(`m${n}`, `<path d="${fr.d}" fill="#000"/>`) +
				`<path d="${fr.d}" fill="none" stroke="${DARK}" stroke-width="5" stroke-linejoin="round" mask="url(#m${n})"/>` +
				`<path d="${fr.d}" fill="none" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/>` +
				glyph + chevrons(t.tier, fr.top),
		};
	} else if (t.mode === "ghost") {
		return {
			fill: `<path d="${fr.d}" fill="#fff" fill-opacity=".18" stroke="#fff" stroke-width="2.4" stroke-dasharray="5 3"/>`,
			overlay: glyph ? `<g opacity=".55">${glyph}</g>` : "",
		};
	}
	const dash = `<path d="${fr.d}" fill="none" stroke="#fff" stroke-width="2.6" stroke-dasharray="4 3"/>`;
	return {
		fill: dash,
		overlay:
			mask(`m${n}`, dash.replace('stroke="#fff"', 'stroke="#000"')) +
			`<path d="${fr.d}" fill="none" stroke="${DARK}" stroke-width="5" opacity=".5" mask="url(#m${n})"/>`,
	};
}

const cell = (t, body) => `<svg x="${t.x}" y="${t.y}" width="${TILE}" height="${TILE}" viewBox="0 -4 48 52">${body}</svg>`;
const sheet = (bodies, size = SHEET) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${bodies.join("")}</svg>`;
const render = (svg) => new Resvg(svg, { fitTo: { mode: "original" }, shapeRendering: 2 }).render();

const fillSvg = sheet(tiles.map((t, i) => cell(t, layers(t, i).fill)));
const overlaySvg = sheet(tiles.map((t, i) => cell(t, layers(t, i).overlay)));
const fillImg = render(fillSvg), overlayImg = render(overlaySvg);

mkdirSync("assets/icons", { recursive: true });
writeFileSync("assets/icons/ftgg-icons-fill.png", fillImg.asPng());
writeFileSync("assets/icons/ftgg-icons-overlay.png", overlayImg.asPng());

// ---- check: tinted fill + overlay == the HTML's own icon ----
const hex = (c) => [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16));
const color = TEAM_COLORS[0];
const original = render(
	sheet(
		tiles.map((t) => {
			const it = t.item ? { ...t.item, t: t.tier } : { f: t.frame };
			const svg = iconSVG(it, color, TILE, t.mode);
			return svg.replace("<svg ", `<svg x="${t.x}" y="${t.y}" `);
		}),
	),
).pixels;
const fp = fillImg.pixels, op = overlayImg.pixels; // premultiplied RGBA (the PNGs are straight)
const tint = hex(color);
let worst = 0, worstAt = -1, sum = 0;
for (let i = 0; i < fp.length; i += 4) {
	// Roblox: fill tinted (rgb * color), overlay alpha-blended over it; all premultiplied
	const oa = op[i + 3] / 255;
	const a = op[i + 3] + fp[i + 3] * (1 - oa);
	const d = Math.max(Math.abs(a - original[i + 3]), ...[0, 1, 2].map((k) => Math.abs(op[i + k] + ((fp[i + k] * tint[k]) / 255) * (1 - oa) - original[i + k])));
	sum += d;
	if (d > worst) (worst = d), (worstAt = i / 4);
}
const px = SHEET * SHEET;
const at = worstAt >= 0 ? tiles[Math.floor((worstAt % SHEET) / TILE) + Math.floor(Math.floor(worstAt / SHEET) / TILE) * COLS] : null;

// ---- previews: every icon in both teams' colors on grass and sand ----
mkdirSync("debug_out/icons", { recursive: true });
const ground = { grass: "#456f38", sand: "#bba878" };
for (const [name, bg] of Object.entries(ground)) {
	const P = 44, cols = 16, rows = Math.ceil(tiles.length / cols) * 2;
	const body = [`<rect width="${cols * P}" height="${rows * P}" fill="${bg}"/>`];
	tiles.forEach((t, i) => {
		for (const [k, c] of TEAM_COLORS.slice(0, 2).entries()) {
			const s = Math.round(28 * (t.mode === "blip" ? 1 : byDefScale(t)));
			const it = t.item ? { ...t.item, t: t.tier } : { f: t.frame };
			const x = (i % cols) * P + (P - s) / 2, y = (Math.floor(i / cols) * 2 + k) * P + (P - s) / 2;
			body.push(iconSVG(it, c, s, t.mode).replace("<svg ", `<svg x="${x}" y="${y}" `));
		}
	});
	writeFileSync(`debug_out/icons/preview-${name}.png`, render(`<svg xmlns="http://www.w3.org/2000/svg" width="${cols * P}" height="${rows * P}">${body.join("")}</svg>`).asPng());
}
function byDefScale(t) {
	return t.item ? t.item.big || SCALE[t.tier] || 1 : 1;
}

// ---- IconAtlas.luau ----
const assets = existsSync("tools/icons/assets.json") ? JSON.parse(readFileSync("tools/icons/assets.json", "utf8")) : {};
const asset = (id) => (id ? `rbxassetid://${String(id).replace(/\D/g, "")}` : "");
const q = (s) => JSON.stringify(s);
const lines = [];
lines.push("--!strict");
lines.push("-- GENERATED by tools/icons/render.mjs from docs/art/icons/ftgg-unit-icons.html");
lines.push("-- (C-74); don't edit. The strategic icon sprite sheets: `fill` (white, tinted");
lines.push("-- with the team color by ImageColor3) under `overlay` (untinted), the same tile");
lines.push("-- on both. Asset ids come from tools/icons/assets.json (\"\" until uploaded).");
lines.push("");
lines.push("local IconAtlas = {}");
lines.push("");
lines.push("export type Entry = { unit: string, ghost: string, scale: number, frame: string, name: string }");
lines.push("");
lines.push(`IconAtlas.fill = ${q(asset(assets.fill))}`);
lines.push(`IconAtlas.overlay = ${q(asset(assets.overlay))}`);
lines.push(`IconAtlas.TILE = ${TILE} -- pixels per icon on the sheets`);
lines.push("");
lines.push("-- tile key → its top-left pixel on both sheets");
lines.push("IconAtlas.tiles = {");
for (const t of tiles) lines.push(`\t${t.key} = { ${t.x}, ${t.y} },`);
lines.push("} :: { [string]: { number } }");
lines.push("");
lines.push("-- unit def id → its icon: unit and ghost tiles, size scale (tier), frame, catalogue name");
lines.push("IconAtlas.byDef = {");
for (const d of defs) {
	const e = byDef[d.id];
	if (e) lines.push(`\t${d.id} = { unit = ${q(e.unit)}, ghost = ${q(e.ghost)}, scale = ${e.scale}, frame = ${q(e.frame)}, name = ${q(e.name)} },`);
}
lines.push("} :: { [string]: Entry }");
lines.push("");
lines.push("-- radar / sonar contacts: the dashed frame with no symbol, by frame");
lines.push("IconAtlas.blips = {");
for (const [f, k] of Object.entries(blips)) lines.push(`\t${f} = ${q(k)},`);
lines.push("} :: { [string]: string }");
lines.push("");
lines.push("return IconAtlas");
writeFileSync("src/client/UI/IconAtlas.luau", lines.join("\n") + "\n");

// ---- report ----
console.log(`${defs.length} unit defs → ${mapping.length} mapped (${mapping.filter((m) => m.how === "family").length} by family), ${items.length} catalogue entries`);
console.log(`${tiles.length} tiles of ${TILE} px (${COLS} x ${COLS} on ${SHEET} px sheets): ${tiles.filter((t) => t.mode === "unit").length} unit, ${tiles.filter((t) => t.mode === "ghost").length} ghost, ${tiles.filter((t) => t.mode === "blip").length} contact`);
console.log(`layers vs the HTML's icon: worst pixel ${worst.toFixed(1)} / 255${at ? ` (${at.key})` : ""}, mean ${(sum / px).toFixed(3)}`);
console.log(`asset ids: fill ${assets.fill || "(none)"}, overlay ${assets.overlay || "(none)"}`);
for (const p of problems) console.log(`PROBLEM: ${p}`);
if (mapping.length < defs.length || worst > 40) process.exit(1);
