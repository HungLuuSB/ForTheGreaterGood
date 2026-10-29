// Faction emblems (E-12): exports the picked pair of docs/art/icons/ftgg-faction-emblems.html to PNG tiles, or
// checks them. The sheet's EMBLEM, EMB, PICK, SIZES and emblemSVG are the source of truth, run from the HTML
// itself as ui_icons.mjs does. Every tile is drawn white with a dark edge (emblemSVG(it, "#ffffff", size)),
// so ImageColor3 tints it (the faction colour is each key's suggested tint).
//
//   node assets/2d/tools/emblems.mjs           writes assets/2d/emblems/: <key>_<size>.png, the atlas
//                                              ftgg-faction-emblems.png and keys.json
//   node assets/2d/tools/emblems.mjs --check   fails (exit 1) if a key is malformed, an emblem is missing,
//                                              the pick isn't one Order and one Chaos emblem, or any file
//                                              is missing or stale
//
// Run from the project root (once: npm install in assets/2d/tools).

import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const HTML = "docs/art/icons/ftgg-faction-emblems.html";
const OUT = "assets/2d/emblems";
const ATLAS_W = 1024;
const GAP = 2; // transparent gutter between atlas tiles, so scaled tiles don't bleed
const check = process.argv.includes("--check");

const html = readFileSync(HTML, "utf8");
const from = html.indexOf("const DARK"), to = html.indexOf("// ---- page ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: DARK / page markers not found`);
const { EMBLEM, EMB, PICK, SIZES, emblemSVG } = new Function(`${html.slice(from, to)}; return { EMBLEM, EMB, PICK, SIZES, emblemSVG };`)();
const picked = EMB.filter((e) => e.dir === PICK);

const problems = [];
for (const it of picked) {
	if (!/^[a-z][a-zA-Z0-9_]*$/.test(it.key)) problems.push(`key "${it.key}" must start lower case and hold only letters, digits and _`);
	if (!EMBLEM[it.key]) problems.push(`key "${it.key}" has no emblem`);
	if (!it.n || !it.faction || !it.tint || !it.use) problems.push(`key "${it.key}" lacks n, faction, tint or use`);
}
const factions = picked.map((e) => e.faction).sort().join(",");
if (factions !== "Chaos,Order") problems.push(`direction ${PICK} should hold one Order and one Chaos emblem, has ${factions || "none"}`);
if (problems.length) {
	for (const p of problems) console.error(`PROBLEM: ${p}`);
	process.exit(1);
}

const png = (svg) => Buffer.from(new Resvg(svg, { fitTo: { mode: "original" } }).render().asPng());

// one tile per key and size, then the atlas (sizes left to right, one row per key; wraps at ATLAS_W)
const files = new Map();
const keys = { sheet: "ftgg-faction-emblems.png", sizes: SIZES, tiles: {} };
const body = [];
let y = 0;
for (const it of picked) {
	let x = 0, rowH = 0;
	for (const size of SIZES) {
		const svg = emblemSVG(it, "#ffffff", size);
		files.set(`${it.key}_${size}.png`, png(svg));
		if (x + size > ATLAS_W) ((x = 0), (y += rowH + GAP), (rowH = 0));
		body.push(svg.replace(/^<svg /, `<svg x="${x}" y="${y}" `));
		const t = (keys.tiles[it.key] ??= { name: it.n, faction: it.faction, tint: it.tint, files: {}, rect: {} });
		t.files[size] = `${it.key}_${size}.png`;
		t.rect[size] = [x, y, size, size]; // ImageRectOffset / ImageRectSize in the atlas
		x += size + GAP;
		rowH = Math.max(rowH, size);
	}
	y += rowH + GAP;
}
const atlasH = y - GAP;
files.set(keys.sheet, png(`<svg xmlns="http://www.w3.org/2000/svg" width="${ATLAS_W}" height="${atlasH}" viewBox="0 0 ${ATLAS_W} ${atlasH}">${body.join("")}</svg>`));
keys.atlasSize = [ATLAS_W, atlasH];
files.set("keys.json", Buffer.from(JSON.stringify(keys, null, "\t") + "\n"));

if (check) {
	const stale = [];
	for (const [name, bytes] of files) {
		const path = `${OUT}/${name}`;
		if (!existsSync(path)) stale.push(`${path} is missing`);
		else {
			const a = readFileSync(path);
			// keys.json may come back from git with CRLF line ends
			const same = name.endsWith(".json") ? a.toString().replace(/\r\n/g, "\n") === bytes.toString() : a.equals(bytes);
			if (!same) stale.push(`${path} is stale`);
		}
	}
	for (const f of existsSync(OUT) ? readdirSync(OUT).filter((f) => !files.has(f)) : []) stale.push(`${OUT}/${f} is no tile of the sheet`);
	for (const s of stale) console.error(`PROBLEM: ${s} (run node assets/2d/tools/emblems.mjs)`);
	console.log(`${picked.length} emblems (direction ${PICK}) × ${SIZES.length} sizes: ${stale.length ? stale.length + " problem(s)" : "every file up to date"}`);
	process.exit(stale.length ? 1 : 0);
}
mkdirSync(OUT, { recursive: true });
for (const [name, bytes] of files) writeFileSync(`${OUT}/${name}`, bytes);
console.log(`${picked.length} emblems (direction ${PICK}) × ${SIZES.length} sizes → ${files.size - 2} tiles, atlas ${ATLAS_W} × ${atlasH} and keys.json in ${OUT}/`);
