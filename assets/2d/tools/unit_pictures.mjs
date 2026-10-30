// Unit pictures (E-11): packs models-C's renders into sprite sheets for the build menu, or checks them.
// C renders one 256 x 256 PNG per def into its debug_out/pictures/ (regenerable, not committed):
//   <id>.png   the unit in its setting (opaque), its paint baked in its faction's colour (Order blue,
//              Chaos red; the user, 2026-10-30: pictures don't follow the player's team colour)
// This scales each to TILE px and packs them into 1024-wide sheets.
//
//   node assets/2d/tools/unit_pictures.mjs [renders]           writes assets/2d/pictures/: the sheets
//                                                              and pictures.json
//   node assets/2d/tools/unit_pictures.mjs --check [renders]   fails (exit 1) if a def that needs a
//                                                              picture has none, a rect is malformed,
//                                                              a sheet is missing, or (with the
//                                                              renders at hand) any file is stale
//
// [renders] defaults to ../FTGG-models/debug_out/pictures. A def with no render yet is listed under
// "missing" in pictures.json (B keeps its live ViewportFrame for it); --check reports how many.
// Packed pictures keep their slot: a new def takes the first free slot (in id order), so adding units
// changes only the sheets they land on, and every other sheet keeps its uploaded image id.
// Run from the project root (once: npm install in assets/2d/tools).

import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { execSync } from "node:child_process";
import { Resvg } from "@resvg/resvg-js";

const OUT = "assets/2d/pictures";
const TILE = 126; // px per picture in the sheet: 8 x 8 fit a 1024 sheet with gutters (128 left one picture alone on a fifth sheet); the build tile is 66 px
const GAP = 2; // transparent gutter between tiles, so scaled tiles don't bleed
const PER_ROW = Math.floor((1024 + GAP) / (TILE + GAP)); // 8
const PER_SHEET = PER_ROW * PER_ROW; // 64
const args = process.argv.slice(2);
const check = args.includes("--check");
const RENDERS = args.find((a) => !a.startsWith("--")) || "../FTGG-models/debug_out/pictures";

// the defs that need a picture: every def that isn't retired
const defs = JSON.parse(execSync("lune run icon_defs", { encoding: "utf8" }))
	.filter((d) => !/retired\s*=\s*true/.test(readFileSync(`src/shared/Defs/Units/${d.id}.luau`, "utf8")))
	.sort((a, b) => (a.id < b.id ? -1 : 1));

const problems = [];
const haveRenders = existsSync(RENDERS);
const renderOf = (id) => [`${RENDERS}/${id}.png`, `${RENDERS}/${id}.jpg`].find((p) => existsSync(p));

const uri = (path) => `data:image/${path.endsWith(".jpg") ? "jpeg" : "png"};base64,${readFileSync(path).toString("base64")}`;
// a render scaled into one tile; a wider render (C's old 512 x 320 portraits) is cropped to its middle square
const tileImage = (path, x, y) =>
	`<svg x="${x}" y="${y}" width="${TILE}" height="${TILE}" viewBox="0 0 1 1" preserveAspectRatio="xMidYMid slice"><image width="1" height="1" preserveAspectRatio="xMidYMid slice" image-rendering="optimizeQuality" href="${uri(path)}"/></svg>`;
const png = (w, h, body) => Buffer.from(new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`, { fitTo: { mode: "original" } }).render().asPng());

// each packed def's slot in the committed pictures.json (sheet-major, row-major), so the layout is stable
function oldSlots() {
	const path = `${OUT}/pictures.json`;
	const slots = new Map();
	if (!existsSync(path)) return slots;
	const old = JSON.parse(readFileSync(path, "utf8"));
	if (old.tile !== TILE) return slots; // a new tile size repacks everything
	for (const [id, u] of Object.entries(old.units)) slots.set(id, (u.sheet - 1) * PER_SHEET + Math.round(u.rect[1] / (TILE + GAP)) * PER_ROW + Math.round(u.rect[0] / (TILE + GAP)));
	return slots;
}

function build(slots) {
	const units = {};
	const missing = [];
	const placed = [];
	for (const d of defs) {
		const pic = haveRenders ? renderOf(d.id) : null;
		if (pic) placed.push({ id: d.id, pic });
		else missing.push(d.id);
	}
	// kept defs stay in their slot; new ones fill the free slots in id order
	const bySlot = new Map();
	for (const u of placed) if (slots.has(u.id)) bySlot.set(slots.get(u.id), u);
	let free = 0;
	for (const u of placed) {
		if (slots.has(u.id)) continue;
		while (bySlot.has(free)) free++;
		bySlot.set(free, u);
	}
	const files = new Map();
	const sheets = [];
	const last = Math.max(-1, ...bySlot.keys());
	for (let s = 0; s * PER_SHEET <= last; s++) {
		const used = [...bySlot.keys()].filter((k) => Math.floor(k / PER_SHEET) === s);
		const rows = used.length ? Math.floor((Math.max(...used) % PER_SHEET) / PER_ROW) + 1 : 1;
		const h = rows * (TILE + GAP) - GAP;
		let body = "";
		for (const k of used.sort((a, b) => a - b)) {
			const u = bySlot.get(k), i = k % PER_SHEET;
			const x = (i % PER_ROW) * (TILE + GAP), y = Math.floor(i / PER_ROW) * (TILE + GAP);
			body += tileImage(u.pic, x, y);
			units[u.id] = { sheet: s + 1, rect: [x, y, TILE, TILE] }; // ImageRectOffset / ImageRectSize
		}
		const sheet = { file: `ftgg-unit-pictures-${s + 1}.png`, size: [1024, h] };
		files.set(sheet.file, png(1024, h, body));
		sheets.push(sheet);
	}
	const json = { tile: TILE, sheets, units: Object.fromEntries(Object.entries(units).sort(([a], [b]) => (a < b ? -1 : 1))), missing };
	files.set("pictures.json", Buffer.from(JSON.stringify(json, null, "\t") + "\n"));
	return { files, json };
}

if (check) {
	const path = `${OUT}/pictures.json`;
	if (!existsSync(path)) {
		console.error(`PROBLEM: ${path} is missing (run node assets/2d/tools/unit_pictures.mjs)`);
		process.exit(1);
	}
	const json = JSON.parse(readFileSync(path, "utf8"));
	const listed = new Set([...Object.keys(json.units), ...json.missing]);
	for (const d of defs) if (!listed.has(d.id)) problems.push(`${d.id} is neither in units nor in missing`);
	for (const id of listed) if (!defs.some((d) => d.id === id)) problems.push(`${id} is no def that needs a picture`);
	for (const [id, u] of Object.entries(json.units)) {
		const sh = json.sheets[u.sheet - 1];
		const [x, y, w, h] = u.rect;
		if (!sh) problems.push(`${id}: sheet ${u.sheet} doesn't exist`);
		else if (w !== json.tile || h !== json.tile || x < 0 || y < 0 || x + w > sh.size[0] || y + h > sh.size[1]) problems.push(`${id}: rect ${u.rect} is outside its sheet`);
	}
	for (const sh of json.sheets) if (!existsSync(`${OUT}/${sh.file}`)) problems.push(`${OUT}/${sh.file} is missing`);
	if (haveRenders) {
		// the renders are here: everything must match a fresh pack
		const { files } = build(oldSlots());
		for (const [name, bytes] of files) {
			const p = `${OUT}/${name}`;
			const a = existsSync(p) ? readFileSync(p) : null;
			const same = a && (name.endsWith(".json") ? a.toString().replace(/\r\n/g, "\n") === bytes.toString() : a.equals(bytes));
			if (!same) problems.push(`${p} is stale against ${RENDERS} (run node assets/2d/tools/unit_pictures.mjs)`);
		}
		for (const f of readdirSync(OUT)) if (!files.has(f)) problems.push(`${OUT}/${f} is no file of the pack`);
	}
	for (const p of problems) console.error(`PROBLEM: ${p}`);
	console.log(`${defs.length} defs need pictures: ${Object.keys(json.units).length} packed on ${json.sheets.length} sheet(s), ${json.missing.length} missing${haveRenders ? "" : " (renders not at hand, files not compared)"}; ${problems.length} problem(s)`);
	process.exit(problems.length ? 1 : 0);
}

const { files, json } = build(oldSlots());
mkdirSync(OUT, { recursive: true });
for (const [name, bytes] of files) writeFileSync(`${OUT}/${name}`, bytes);
console.log(`${defs.length} defs need pictures: ${Object.keys(json.units).length} packed on ${json.sheets.length} sheet(s) (${TILE} px tiles, ${PER_SHEET} a sheet), ${json.missing.length} missing → ${OUT}/`);
