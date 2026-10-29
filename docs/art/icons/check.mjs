// Checks an icon sheet against the unit defs (E-4): every def is in exactly
// one catalogue item, no item lists an id that is no def, each item's tier
// and frame agree with its defs, every symbol exists, tile keys are unique,
// and the ten placeholders (one per frame, ph:1, no defs, no tier) are there.
// Runs the sheet's own FR / SYM / CAT the way tools/icons/render.mjs does.
//
// From the project root:
//   node docs/art/icons/check.mjs [sheet.html]   (default docs/art/icons/ftgg-unit-icons.html)
// Exits 1 on any problem; notes (tier differences the sheet chose) don't fail.

import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";

const HTML = process.argv[2] || "docs/art/icons/ftgg-unit-icons.html";
const html = readFileSync(HTML, "utf8");
const from = html.indexOf("const DARK");
const to = html.indexOf("// ---- state ----");
if (from < 0 || to < 0) throw new Error(`${HTML}: DARK / state markers not found`);
const { FR, SYM, CAT } = new Function(`${html.slice(from, to)}; return { FR, SYM, CAT };`)();

// icon_defs gives id, domain, tier and name; the move class, retired flag and
// weapons (for the frame rule) come from the def files
const defs = JSON.parse(execSync("lune run icon_defs", { encoding: "utf8" }));
for (const d of defs) {
	const src = readFileSync(`src/shared/Defs/Units/${d.id}.luau`, "utf8");
	d.move = (src.match(/moveClass\s*=\s*"(\w+)"/) || [])[1] || "";
	d.retired = /retired\s*=\s*true/.test(src);
	d.armed = /weapons\s*=\s*\{\s*\{/.test(src);
}

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
const PH_FRAMES = ["vehicle", "walker", "amphib", "hover", "air", "vtol", "ship", "sub", "struct", "defense"];
// the frame a def should have, by the placeholder rule
function frameFor(d) {
	if (d.domain === "structure") return d.armed ? "defense" : "struct";
	if (d.domain === "air") return d.move === "HELI" ? "vtol" : "air";
	if (d.domain === "naval") return d.move === "SUB" ? "sub" : "ship";
	if (d.move === "WALKER" || d.move === "AMPHIB_WALKER") return "walker";
	if (d.move === "AMPHIB") return "amphib";
	if (d.move === "HOVER") return "hover";
	return "vehicle";
}

const problems = [];
const notes = [];
const items = CAT.flatMap((s) => s.items);
const itemOf = new Map();
const keys = new Map();
const phSeen = new Map();
for (const it of items) {
	if (!FR[it.f]) problems.push(`"${it.n}": unknown frame ${it.f}`);
	if (!SYM[it.s]) problems.push(`"${it.n}": unknown symbol ${it.s}`);
	const key = `${slug(it.n)}_t${it.t}`;
	if (keys.has(key)) problems.push(`tile key ${key} is used by "${keys.get(key)}" and "${it.n}"`);
	keys.set(key, it.n);
	const ids = String(it.defs || "").split(/\s+/).filter(Boolean);
	if (it.ph) {
		if (ids.length) problems.push(`placeholder "${it.n}" lists defs`);
		if (it.t !== 0) problems.push(`placeholder "${it.n}" has tier ${it.t} (placeholders carry no dots)`);
		if (phSeen.has(it.f)) problems.push(`two placeholders for frame ${it.f}`);
		phSeen.set(it.f, it);
		continue;
	}
	if (!ids.length) problems.push(`"${it.n}" has no defs`);
	for (const id of ids) {
		if (itemOf.has(id)) problems.push(`${id} is listed under "${itemOf.get(id).n}" and "${it.n}"`);
		else itemOf.set(id, it);
	}
}
for (const f of PH_FRAMES) if (!phSeen.has(f)) problems.push(`no placeholder for frame ${f}`);

const known = new Map(defs.map((d) => [d.id, d]));
for (const [id, it] of itemOf) if (!known.has(id)) problems.push(`"${it.n}" lists ${id}, which is no unit def`);
let retired = 0;
for (const d of defs) {
	const it = itemOf.get(d.id);
	if (!it) {
		problems.push(`${d.id} (${d.name}) is in no catalogue item`);
		continue;
	}
	if (d.retired) retired++;
	if (it.t !== d.tier) notes.push(`${d.id}: "${it.n}" is drawn T${it.t}, the def is T${d.tier}`);
	// mobile units must wear their movement's frame; a structure may pick struct
	// or defense by role (the shield dome is a defense, the nuke silo is not)
	const want = frameFor(d);
	if (d.domain === "structure") {
		if (it.f !== "struct" && it.f !== "defense") problems.push(`${d.id}: structure "${it.n}" uses frame ${it.f}`);
		else if (it.f !== want) notes.push(`${d.id}: "${it.n}" uses frame ${it.f} (the placeholder rule would pick ${want})`);
	} else if (it.f !== want) problems.push(`${d.id} (${d.domain}, ${d.move || "no move class"}): "${it.n}" uses frame ${it.f}, the rule says ${want}`);
}

for (const n of notes) console.log(`note: ${n}`);
for (const p of problems) console.error(`PROBLEM: ${p}`);
const units = items.filter((i) => !i.ph).length;
console.log(`${HTML}: ${defs.length} defs (${retired} retired) → ${itemOf.size} mapped once over ${units} icons + ${phSeen.size} placeholders; ${keys.size} tile keys; ${problems.length} problem(s)`);
process.exit(problems.length ? 1 : 0);
