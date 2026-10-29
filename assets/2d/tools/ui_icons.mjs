// UI icons (E-7): exports docs/art/icons/ftgg-ui-icons.html to PNG tiles, or checks them.
// The sheet's GLYPH, UI, SIZES and uiSVG are the source of truth and are run from the HTML
// itself, as tools/icons/render.mjs does for the unit icons. Every tile is drawn white with a
// dark edge (uiSVG(it, "#ffffff", size)), so ImageColor3 tints it.
//
//   node assets/2d/tools/ui_icons.mjs           writes assets/2d/ui/: <key>_<size>.png, the atlas
//                                               ftgg-ui-icons.png and keys.json
//   node assets/2d/tools/ui_icons.mjs --check   fails (exit 1) if a key is malformed or repeated,
//                                               a glyph is missing, or any file is missing or stale
//
// Run from the project root (once: npm install in assets/2d/tools).

import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { Resvg } from "@resvg/resvg-js";

const HTML = "docs/art/icons/ftgg-ui-icons.html";
const OUT = "assets/2d/ui";
const ATLAS_W = 1024; // Roblox's largest image side
const GAP = 2; // transparent gutter between atlas tiles, so scaled tiles don't bleed
const check = process.argv.includes("--check");

const html = readFileSync(HTML, "utf8");
const from = html.indexOf("const DARK"), to = html.indexOf("// ---- page ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: DARK / page markers not found`);
const { UI, SIZES, GLYPH, uiSVG } = new Function(`${html.slice(from, to)}; return { UI, SIZES, GLYPH, uiSVG };`)();

const problems = [];
const seen = new Set();
for (const it of UI) {
	// lower case first, then letters, digits or _ (camel case like the Codex's airSight is allowed)
	if (!/^[a-z][a-zA-Z0-9_]*$/.test(it.key)) problems.push(`key "${it.key}" must start lower case and hold only letters, digits and _`);
	if (seen.has(it.key)) problems.push(`key "${it.key}" is used twice`);
	seen.add(it.key);
	if (!GLYPH[it.key]) problems.push(`key "${it.key}" has no glyph`);
	if (!it.n || !it.group || !it.tint || !it.use) problems.push(`key "${it.key}" lacks n, group, tint or use`);
}
if (problems.length) {
	for (const p of problems) console.error(`PROBLEM: ${p}`);
	process.exit(1);
}

const png = (svg) => Buffer.from(new Resvg(svg, { fitTo: { mode: "original" } }).render().asPng());

// the files: one tile per key and size, then the atlas (one row band per size, wrapping at ATLAS_W)
const files = new Map(); // name -> bytes
const keys = { sheet: "ftgg-ui-icons.png", sizes: SIZES, tiles: {} };
let y = 0;
const body = [];
for (const size of SIZES) {
	let x = 0, rowH = size;
	for (const it of UI) {
		const svg = uiSVG(it, "#ffffff", size);
		files.set(`${it.key}_${size}.png`, png(svg));
		if (x + size > ATLAS_W) ((x = 0), (y += rowH + GAP));
		body.push(svg.replace(/^<svg /, `<svg x="${x}" y="${y}" `));
		const t = (keys.tiles[it.key] ??= { name: it.n, group: it.group, tint: it.tint, files: {}, rect: {} });
		t.files[size] = `${it.key}_${size}.png`;
		t.rect[size] = [x, y, size, size]; // x, y, width, height in the atlas (ImageRectOffset / ImageRectSize)
		x += size + GAP;
	}
	y += rowH + GAP;
}
const atlasH = y - GAP;
files.set("ftgg-ui-icons.png", png(`<svg xmlns="http://www.w3.org/2000/svg" width="${ATLAS_W}" height="${atlasH}" viewBox="0 0 ${ATLAS_W} ${atlasH}">${body.join("")}</svg>`));
keys.atlasSize = [ATLAS_W, atlasH];
files.set("keys.json", Buffer.from(JSON.stringify(keys, null, "\t") + "\n"));

// keys.json may come back from git with CRLF line ends (core.autocrlf), so text compares without them
const sameFile = (a, b, name) =>
	name.endsWith(".json") ? a.toString().replace(/\r\n/g, "\n") === b.toString() : a.equals(b);

if (check) {
	const stale = [];
	for (const [name, bytes] of files) {
		const path = `${OUT}/${name}`;
		if (!existsSync(path)) stale.push(`${path} is missing`);
		else if (!sameFile(readFileSync(path), bytes, name)) stale.push(`${path} is stale`);
	}
	const extra = existsSync(OUT) ? readdirSync(OUT).filter((f) => !files.has(f)) : [];
	for (const f of extra) stale.push(`${OUT}/${f} is no tile of the sheet`);
	for (const s of stale) console.error(`PROBLEM: ${s} (run node assets/2d/tools/ui_icons.mjs)`);
	console.log(`${UI.length} UI icons × ${SIZES.length} sizes: ${stale.length ? stale.length + " problem(s)" : "every file up to date"}`);
	process.exit(stale.length ? 1 : 0);
}
mkdirSync(OUT, { recursive: true });
for (const [name, bytes] of files) writeFileSync(`${OUT}/${name}`, bytes);
console.log(`${UI.length} UI icons × ${SIZES.length} sizes → ${files.size - 2} tiles, atlas ${ATLAS_W} × ${atlasH} and keys.json in ${OUT}/`);
