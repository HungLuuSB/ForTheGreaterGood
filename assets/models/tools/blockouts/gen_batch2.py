"""Writes the hand-made blockouts of the BAR roster's batch 2 (bots, the
user's approval 2026-11-01; sim-A's list in docs/progress/sim.md "For the
models stream (C)" item 5):

    python gen_batch2.py <src/shared/Defs/Blockouts> [pieces.json]

pieces.json ({id: [piece, ...]}, dumped from the defs) fits each rig to its
def once the defs land: only def pieces (and the client's leg pieces) pivot,
decorations hang from their nearest piece.

41 silhouettes from the roles, ahead of the defs. The decoy Commanders
(`ord_effigy`, `chs_changeling`) get none: their defs point `model` at the
real Commander's, so they look the same up close. Our own designs: BAR's
pictures and models are looked at only (CC BY-NC-ND). Walkers use the leg
kit (Bots.legs, client pieces `thigh` / `shin` / `foot` L and R); the
all-terrain spiders use Bots.spider (four or six legs, high knees, claw
tips). Pieces follow ours: `base` (the pelvis or body), a yawing `torso`,
pitching `launcher` / `barrel` where a weapon aims up, a `nano` arm on
builders, a spinning `radar` (client piece) on radar bots; muzzles and
`nano1` attachments. Order reads clean and heavy (team panels, sloped
plates, cyan glow); Chaos crude and angular (open frames, spikes, amber).
Big mechs are laid out at about bot size and scaled with Scale.scaled.
Model space, forward = -Z, ground at y = 0.
"""
import json
import os
import sys

OUT = sys.argv[1]
PIECES = json.load(open(sys.argv[2], encoding="utf-8")) if len(sys.argv) > 2 else {}

HEADER = "Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z."


def f(v):
    return f"{round(v, 3):g}"


def vec(v):
    return "{ " + ", ".join(f(x) for x in v) + " }"


class U:
    def __init__(self, uid, comment, scale=None):
        self.uid, self.comment, self.scale = uid, comment, scale
        self.parts, self.att, self.visual = [], [], []
        self.legs = None  # ("legs" | "spider", {opts})

    def part(self, name, shape, size, at, color, parent="torso", rot=None, axis=None, pivot=None, anim=None):
        self.parts.append(dict(name=name, shape=shape, size=size, at=at, color=color, parent=parent, rot=rot,
                               axis=axis, pivot=pivot, anim=anim))

    def attach(self, name, parent, at):
        self.att.append(dict(name=name, parent=parent, at=at))

    def fit(self, pieces):
        """Matches the def's pieces: only pieces (and the client pieces) pivot;
        a decoration's children hang from its nearest piece."""
        if not pieces:
            return
        keep = set(pieces) | set(self.visual)
        parent = {p["name"]: p["parent"] for p in self.parts}

        def piece_of(name):
            while name != "base" and name not in keep:
                name = parent[name]
            return name

        for p in self.parts:
            if p["name"] != "base":
                p["parent"] = piece_of(p["parent"])
            if p["pivot"] and p["name"] not in keep:
                p["pivot"] = None
        names = {p["name"] for p in self.parts}
        for a in list(self.att):
            a["parent"] = piece_of(a["parent"])
            muzzle = a["name"].startswith("muzzle") or "_muzzle" in a["name"]
            if a["name"] in pieces and not muzzle:  # e.g. `nano1` listed in the def: a marker part
                self.att.remove(a)
                if a["name"] not in names:
                    self.part(a["name"], "ball", (0.3, 0.3, 0.3), a["at"], "dark", parent=a["parent"])

    def write(self):
        lines = ["--!strict"] + [f"-- {c}" if c else "--" for c in self.comment] + [""]
        if self.legs:
            lines += ['local Bots = require("./Bots")', ""]
        base, rest = self.parts[0], self.parts[1:]
        lines.append("local parts: { any } = {")
        lines.append("\t" + self.fmt(base) + ",")
        lines.append("}")
        if self.legs:
            kind, o = self.legs
            opts = ", ".join(f'{k} = "{v}"' if isinstance(v, str) else f"{k} = {str(v).lower() if isinstance(v, bool) else f(v)}"
                             for k, v in o.items())
            lines.append(f"local visual = Bots.{kind}(parts, {{ {opts} }})")
        else:
            lines.append("local visual: { string } = {}")
        for v in self.visual:
            lines.append(f'table.insert(visual, "{v}")')
        lines.append("for _, p in {")
        lines += ["\t" + self.fmt(p) + "," for p in rest]
        lines.append("} do")
        lines.append("\ttable.insert(parts, p)")
        lines.append("end")
        lines.append("")
        body = ["{", f'\tid = "{self.uid}",', "\tparts = parts,", "\tvisualPieces = visual,"]
        if self.att:
            body.append("\tattachments = {")
            body += [f'\t\t{{ name = "{a["name"]}", parent = "{a["parent"]}", at = {vec(a["at"])} }},' for a in self.att]
            body.append("\t},")
        if self.scale:
            lines.append('return require("./Scale").scaled(' + body[0])
            lines += body[1:]
            lines.append(f"}}, {f(self.scale)})")
        else:
            lines.append("return " + body[0])
            lines += body[1:]
            lines.append("}")
        with open(os.path.join(OUT, f"{self.uid}.luau"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")

    @staticmethod
    def fmt(p):
        s = f'{{ name = "{p["name"]}"'
        if p["name"] != "base":
            s += f', parent = "{p["parent"]}"'
        s += f', shape = "{p["shape"]}"'
        if p["axis"]:
            s += f', axis = "{p["axis"]}"'
        s += f", size = {vec(p['size'])}, at = {vec(p['at'])}"
        if p["rot"]:
            s += f", rot = {vec(p['rot'])}"
        if p["pivot"]:
            s += f", pivot = {vec(p['pivot'])}"
        s += f', color = "{p["color"]}"'
        if p["anim"]:
            s += f', anim = {{ motion = "{p["anim"][0]}", axis = {vec(p["anim"][1])} }}'
        return s + " }"


# ---------------------------------------------------------------------------
# kits
# ---------------------------------------------------------------------------


def biped(u, hip, hx, thick, w, d, color="hull", team=False, foot=None, pelvis="hull"):
    """Pelvis (`base`) and the leg kit; returns the pelvis top."""
    u.part("base", "box", (w, 0.8, d), (0, hip + 0.2, 0), pelvis, parent=None)
    o = dict(hipY=hip, hipX=hx, thick=thick, color=color)
    if foot:
        o["foot"] = foot
    if team:
        o["team"] = True
    u.legs = ("legs", o)
    return hip + 0.6


def spider(u, legs, body, body_y, hipR, kneeR, kneeY, footR, thick, color="hull", team=False, shin=None, body_color="hull"):
    """Body (`base`) and the spider kit."""
    u.part("base", "box", body, (0, body_y, 0), body_color, parent=None)
    o = dict(legs=legs, hipR=hipR, hipY=body_y, kneeR=kneeR, kneeY=kneeY, footR=footR, thick=thick, color=color)
    if shin:
        o["shin"] = shin
    if team:
        o["team"] = True
    u.legs = ("spider", o)


def torso(u, w, h, d, y0, color="hull", z=0.0, pivot_z=0.0):
    """The yawing `torso`, its bottom at y0; returns its top."""
    u.part("torso", "box", (w, h, d), (0, y0 + h / 2, z), color, parent="base", pivot=(0, y0, pivot_z))
    return y0 + h


def head(u, y, z, w, h, d, faction, visor=True, color="hull"):
    u.part("head", "box", (w, h, d), (0, y + h / 2, z), color)
    if visor:
        u.part("visor", "box", (w * 0.75, h * 0.28, 0.08), (0, y + h * 0.55, z - d / 2 - 0.03), "glass")


def gun(u, name, x, y, z0, length, bore, color="metal", parent="torso", tip="dark", glow=False):
    """A barrel along -Z from z0; returns the mouth's z."""
    u.part(name, "cylinder", (bore, bore, length), (x, y, z0 - length / 2), color, parent=parent, axis="z")
    zt = z0 - length
    u.part(name + "Tip", "cylinder", (bore * 1.25, bore * 1.25, 0.2), (x, y, zt - 0.05), "glass" if glow else tip,
           parent=parent, axis="z")
    return zt - 0.15


def spikes(u, xs, y, z, h=0.7, w=0.3, d=0.5, parent="torso", prefix="spike", color="metal"):
    for i, x in enumerate(xs):
        u.part(f"{prefix}{i + 1}", "wedge", (w, h, d), (x, y + h / 2, z), color, parent=parent)


def tubes(u, prefix, cx, cy, z, cols, rows, pitch, r, parent, color="glass"):
    """A grid of tube mouths facing -Z, centred on (cx, cy) at depth z."""
    for i in range(cols):
        for j in range(rows):
            x = cx + (i - (cols - 1) / 2) * pitch
            y = cy + (j - (rows - 1) / 2) * pitch
            u.part(f"{prefix}{i + 1}{j + 1}", "cylinder", (r, r, 0.12), (x, y, z), color, parent=parent, axis="z")


def nano_arm(u, x, y, z, length, faction, parent="torso", rise=0.0):
    """Builder arm: the `nano` piece (yaws, pitches) with an emitter; adds `nano1`."""
    u.part("nano", "box", (0.45, 0.45, length), (x, y + rise / 2, z - length / 2), "metal", parent=parent,
           pivot=(x, y, z), rot=(-(rise / length) * 57.3, 0, 0) if rise else None)
    tip = (x, y + rise, z - length)
    if faction == "order":
        u.part("nanoHead", "cylinder", (0.55, 0.55, 0.45), tip, "team", parent="nano", axis="z")
        u.part("nanoGlow", "ball", (0.4, 0.4, 0.4), (tip[0], tip[1], tip[2] - 0.3), "glass", parent="nano")
    else:
        u.part("nanoClawL", "wedge", (0.15, 0.5, 0.6), (tip[0] - 0.2, tip[1], tip[2] - 0.2), "dark", parent="nano")
        u.part("nanoClawR", "wedge", (0.15, 0.5, 0.6), (tip[0] + 0.2, tip[1], tip[2] - 0.2), "dark", parent="nano")
        u.part("nanoGlow", "ball", (0.32, 0.32, 0.32), (tip[0], tip[1], tip[2] - 0.25), "glass", parent="nano")
    u.attach("nano1", "nano", (tip[0], tip[1], tip[2] - 0.5))


def radar(u, x, y, z, w, h, parent="torso"):
    """A spinning `radar` (client piece) on a mast top."""
    u.part("radar", "box", (w, h, 0.3), (x, y, z), "dark", parent=parent, anim=("turn", (0, 1, 0)), pivot=(x, y, z))
    u.part("radarFace", "box", (w * 0.85, h * 0.6, 0.08), (x, y, z - 0.18), "glass", parent="radar")
    u.visual.append("radar")


# ---------------------------------------------------------------------------
# Order
# ---------------------------------------------------------------------------


def order():
    out = []

    u = U("ord_picket", ["Picket (Order anti-swarm bot, T1): a stocky upright bot with a broad chest", "plate and big shoulder pads; both forearms end in close-range laser", "emitters (`muzzle`, `muzzle2`). " + HEADER])
    y = biped(u, 2.5, 0.85, 0.65, 2.0, 1.5, team=True)
    t = torso(u, 2.6, 1.8, 2.0, y)
    u.part("chest", "wedge", (2.2, 1.1, 0.6), (0, y + 1.0, -1.25), "team")
    head(u, t, -0.2, 1.0, 0.6, 0.9, "order")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("pad" + n, "box", (0.9, 0.6, 1.8), (s * 1.6, t - 0.1, 0), "team")
        u.part("arm" + n, "box", (0.7, 1.5, 0.8), (s * 1.65, y + 0.75, -0.2), "metal")
        u.part("laser" + n, "box", (0.8, 0.7, 1.5), (s * 1.65, y + 0.2, -0.9), "hull")
        u.part("lens" + n, "cylinder", (0.5, 0.5, 0.12), (s * 1.65, y + 0.2, -1.72), "glass", axis="z")
    u.attach("muzzle", "torso", (1.65, y + 0.2, -1.85))
    u.attach("muzzle2", "torso", (-1.65, y + 0.2, -1.85))
    out.append(u)

    u = U("ord_squire", ["Squire (Order fast infantry bot, T1): small and light on quick legs, a compact", "body with a visor, a plasma gun on the right arm, an antenna. " + HEADER])
    y = biped(u, 1.9, 0.5, 0.4, 1.2, 1.0, team=True)
    t = torso(u, 1.5, 1.2, 1.3, y)
    u.part("chestTeam", "box", (0.9, 0.45, 0.08), (0, y + 0.65, -0.68), "team")
    head(u, t, -0.1, 0.8, 0.5, 0.75, "order")
    u.part("pack", "box", (1.1, 0.9, 0.5), (0, y + 0.65, 0.9), "dark")
    u.part("antenna", "cylinder", (0.08, 1.4, 0.08), (-0.45, t + 0.7, 0.8), "dark", axis="y")
    u.part("arm", "box", (0.45, 0.45, 1.1), (0.95, y + 0.55, -0.4), "metal")
    z = gun(u, "gun", 0.95, y + 0.55, -0.95, 1.0, 0.3, glow=True)
    u.part("armL", "box", (0.4, 0.9, 0.45), (-0.95, y + 0.55, 0), "metal")
    u.attach("muzzle", "torso", (0.95, y + 0.55, z))
    out.append(u)

    u = U("ord_petard", ["Petard (Order rocket bot, T1): an upright bot carrying a square rocket pod on", "its right shoulder, four tubes facing forward, a sensor head on the left. " + HEADER])
    y = biped(u, 2.5, 0.7, 0.55, 1.8, 1.4, team=True)
    t = torso(u, 2.0, 1.6, 1.7, y)
    u.part("chestTeam", "box", (0.9, 0.5, 0.08), (-0.3, y + 0.9, -0.88), "team")
    head(u, t, -0.1, 0.8, 0.55, 0.8, "order")
    u.part("pod", "box", (1.4, 1.3, 1.8), (1.5, t + 0.2, 0.1), "team")
    u.part("podFace", "box", (1.2, 1.1, 0.1), (1.5, t + 0.2, -0.82), "dark")
    tubes(u, "tube", 1.5, t + 0.2, -0.9, 2, 2, 0.5, 0.36, "torso")
    u.part("armL", "box", (0.45, 1.1, 0.5), (-1.25, y + 0.7, 0), "metal")
    u.attach("muzzle", "torso", (1.5, t + 0.2, -1.05))
    out.append(u)

    u = U("ord_draftsman", ["Draftsman (Order advanced constructor bot, T2): a heavier worker than the", "Artisan, a broad body with a team backpack and a long jointed construction arm", "(`nano`) over the right shoulder, a short tool arm on the left. " + HEADER])
    y = biped(u, 2.8, 0.85, 0.65, 2.0, 1.6, team=True)
    t = torso(u, 2.5, 1.9, 2.1, y)
    head(u, t, -0.4, 1.0, 0.6, 0.9, "order")
    u.part("pack", "box", (2.0, 1.6, 0.9), (0, y + 1.0, 1.45), "team")
    u.part("packGlow", "box", (1.4, 0.15, 0.06), (0, y + 1.6, 1.92), "glass")
    u.part("mount", "cylinder", (0.9, 0.5, 0.9), (1.3, t + 0.25, 0.2), "metal", axis="y")
    nano_arm(u, 1.3, t + 0.5, 0.2, 3.2, "order", rise=0.6)
    u.part("tool", "box", (0.5, 1.2, 0.5), (-1.5, y + 0.6, -0.3), "metal")
    u.part("toolTip", "box", (0.6, 0.3, 0.7), (-1.5, y - 0.05, -0.6), "hazard")
    out.append(u)

    u = U("ord_skyguard", ["Skyguard (Order amphibious anti-air bot, T2): a rounded, sealed body with float", "collars at the hips and two missile pods on the shoulders that pitch up", "together (`launcher`), cells glowing on their faces. " + HEADER])
    y = biped(u, 2.6, 0.8, 0.65, 2.0, 1.6, team=True)
    t = torso(u, 2.2, 1.7, 2.0, y)
    u.part("dome", "ball", (2.0, 1.2, 1.8), (0, t - 0.1, 0), "hull")
    u.part("visor", "box", (1.2, 0.25, 0.08), (0, y + 1.25, -1.03), "glass")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("float" + n, "cylinder", (0.8, 0.8, 1.8), (s * 1.45, y - 0.3, 0), "team", parent="base", axis="z")
    py = t + 0.2
    u.part("launcher", "box", (0.6, 0.4, 0.6), (0, py, 0.2), "metal", pivot=(0, py, 0.2))
    for s, n in ((-1, "L"), (1, "R")):
        u.part("pod" + n, "box", (0.9, 1.0, 1.6), (s * 1.6, py, 0), "hull", parent="launcher")
        u.part("podTeam" + n, "box", (0.06, 0.6, 1.2), (s * 2.07, py, 0), "team", parent="launcher")
        tubes(u, "cell" + n, s * 1.6, py, -0.82, 2, 2, 0.4, 0.28, "launcher")
    u.attach("muzzle", "launcher", (1.6, py, -1.0))
    out.append(u)

    u = U("ord_steward", ["Steward (Order fast assist and repair bot, T2): light and long-legged, a", "small body with a crane arm (`nano`) arching from its back over the head. " + HEADER])
    y = biped(u, 2.7, 0.55, 0.42, 1.3, 1.1, team=True)
    t = torso(u, 1.5, 1.2, 1.3, y)
    head(u, t, -0.2, 0.7, 0.45, 0.7, "order")
    u.part("chestTeam", "box", (0.8, 0.4, 0.08), (0, y + 0.65, -0.68), "team")
    u.part("mast", "box", (0.35, 1.6, 0.35), (0.35, t + 0.5, 0.6), "metal")
    nano_arm(u, 0.35, t + 1.3, 0.6, 2.4, "order", rise=-0.6)
    out.append(u)

    u = U("ord_sextant", ["Sextant (Order radar bot, T2): a compact bot carrying a mast on its back with", "a big tilted radar dish (`radar`, spins). " + HEADER])
    y = biped(u, 2.2, 0.6, 0.5, 1.4, 1.2, team=True)
    t = torso(u, 1.6, 1.3, 1.4, y)
    head(u, t, -0.2, 0.8, 0.45, 0.7, "order")
    u.part("chestTeam", "box", (0.9, 0.45, 0.08), (0, y + 0.7, -0.73), "team")
    u.part("mast", "cylinder", (0.2, 2.0, 0.2), (0, t + 1.0, 0.6), "metal", axis="y")
    u.part("radar", "cylinder", (2.6, 0.15, 2.6), (0, t + 2.1, 0.6), "dark", axis="y", rot=(25, 0, 0),
           anim=("turn", (0, 1, 0)), pivot=(0, t + 2.0, 0.6))
    u.part("radarFace", "cylinder", (2.3, 0.06, 2.3), (0, t + 2.2, 0.55), "team", parent="radar", axis="y", rot=(25, 0, 0))
    u.part("feed", "ball", (0.35, 0.35, 0.35), (0, t + 2.6, 0.35), "glass", parent="radar")
    u.visual.append("radar")
    out.append(u)

    u = U("ord_informant", ["Informant (Order cloaked spy bot, T2): small and crouched, dark faceted plates,", "one glowing eye and the EMP charge glowing in its back. " + HEADER])
    y = biped(u, 1.5, 0.45, 0.35, 1.0, 0.9, color="dark", pelvis="dark")
    u.part("torso", "wedge", (1.3, 0.9, 1.6), (0, y + 0.45, -0.1), "dark", parent="base", pivot=(0, y, 0))
    u.part("back", "box", (1.3, 0.9, 0.5), (0, y + 0.45, 0.9), "dark")
    u.part("core", "cylinder", (0.6, 0.6, 0.12), (0, y + 0.5, 1.18), "glass", axis="z")
    u.part("eye", "ball", (0.35, 0.35, 0.35), (0, y + 0.35, -0.85), "glass")
    u.part("teamFin", "box", (0.08, 0.3, 0.7), (0, y + 1.05, 0.6), "team")
    u.attach("muzzle", "torso", (0, y + 0.35, -1.05))
    out.append(u)

    u = U("ord_marshal", ["Marshal (Order skirmisher bot, gauss guns, T2): tall and lean, both forearms", "long gauss rails with glowing coils (`muzzle`, `muzzle2`). " + HEADER])
    y = biped(u, 3.0, 0.7, 0.55, 1.7, 1.4, team=True)
    t = torso(u, 2.0, 1.6, 1.6, y)
    head(u, t, -0.2, 0.8, 0.5, 0.8, "order")
    u.part("chest", "wedge", (1.6, 0.9, 0.5), (0, y + 1.0, -1.0), "team")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        u.part("arm" + n, "box", (0.55, 1.1, 0.6), (s * 1.35, y + 0.75, 0), "metal")
        u.part("rail" + n, "box", (0.5, 0.45, 3.0), (s * 1.35, y + 0.2, -1.2), "hull")
        for i in range(2):
            u.part(f"coil{n}{i + 1}", "box", (0.62, 0.57, 0.15), (s * 1.35, y + 0.2, -0.6 - i * 0.9), "glass")
        u.attach(m, "torso", (s * 1.35, y + 0.2, -2.85))
    out.append(u)

    u = U("ord_culverin", ["Culverin (Order mortar bot, T2): a squat, wide bot with a short fat mortar", "(`barrel`, pitches) on its back and a team shield plate on its chest. " + HEADER])
    y = biped(u, 2.2, 0.9, 0.7, 2.0, 1.6, team=True)
    t = torso(u, 2.4, 1.4, 2.2, y)
    u.part("shield", "wedge", (2.2, 1.2, 0.6), (0, y + 0.7, -1.4), "team")
    u.part("visor", "box", (1.0, 0.2, 0.08), (0, t - 0.25, -1.13), "glass")
    py = t + 0.3
    u.part("cradle", "box", (1.2, 0.6, 1.2), (0, t + 0.3, 0.5), "metal")
    u.part("barrel", "cylinder", (0.8, 0.8, 2.0), (0, py + 0.7, -0.2), "dark", axis="z", rot=(45, 0, 0), pivot=(0, py, 0.5))
    u.part("mouthRing", "cylinder", (0.95, 0.95, 0.2), (0, py + 1.35, -0.85), "glass", parent="barrel", axis="z", rot=(45, 0, 0))
    u.attach("muzzle", "barrel", (0, py + 1.45, -0.95))
    out.append(u)

    u = U("ord_mariner", ["Mariner (Order amphibious bot, light laser, T2): a rounded hull-like body with", "a raked bow, team float tanks on its flanks, a snorkel and a small laser on top. " + HEADER])
    y = biped(u, 2.3, 0.75, 0.6, 1.8, 1.5, team=True)
    t = torso(u, 2.0, 1.4, 2.0, y)
    u.part("bow", "wedge", (2.0, 1.4, 0.8), (0, y + 0.7, -1.4), "hull")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("tank" + n, "cylinder", (0.7, 0.7, 2.0), (s * 1.3, y + 0.6, 0.1), "team", axis="z")
    u.part("snorkel", "cylinder", (0.25, 1.3, 0.25), (-0.6, t + 0.6, 0.7), "metal", axis="y")
    u.part("laserMount", "box", (0.6, 0.45, 0.7), (0.3, t + 0.22, -0.2), "metal")
    z = gun(u, "laser", 0.3, t + 0.25, -0.55, 1.0, 0.28, glow=True)
    u.part("visor", "box", (1.2, 0.2, 0.08), (0, y + 1.0, -1.45), "glass")
    u.attach("muzzle", "torso", (0.3, t + 0.25, z))
    out.append(u)

    u = U("ord_scaler", ["Scaler (Order all-terrain rocket spider, T2): a flat armoured body on six", "long jointed legs with high knees and claw tips, a rocket box on its back", "(`torso`) with six tubes. " + HEADER])
    spider(u, 6, (1.8, 0.9, 2.6), 2.2, 0.9, 2.3, 3.7, 3.4, 0.3, team=True)
    u.part("plate", "wedge", (1.8, 0.6, 0.8), (0, 2.2, -1.65), "hull", parent="base")
    u.part("torso", "box", (1.6, 0.9, 1.6), (0, 3.15, 0.1), "team", parent="base", pivot=(0, 2.7, 0.1))
    u.part("rackFace", "box", (1.4, 0.7, 0.1), (0, 3.15, -0.75), "dark")
    tubes(u, "tube", 0, 3.15, -0.82, 3, 2, 0.42, 0.3, "torso")
    u.part("eye", "box", (0.8, 0.15, 0.08), (0, 2.35, -2.05), "glass", parent="base")
    u.attach("muzzle", "torso", (0, 3.15, -0.95))
    out.append(u)

    u = U("ord_marksman", ["Marksman (Order cloaked sniper bot, T2): slim and dark with a hooded sensor", "head, holding a very long rifle with a scope at the shoulder. " + HEADER])
    y = biped(u, 3.0, 0.6, 0.45, 1.4, 1.2, color="dark", team=True)
    t = torso(u, 1.6, 1.4, 1.4, y, color="dark")
    u.part("hood", "wedge", (0.9, 0.6, 1.0), (0, t + 0.3, -0.1), "dark")
    u.part("eye", "box", (0.6, 0.12, 0.06), (0, t + 0.2, -0.62), "glass")
    u.part("arm", "box", (0.45, 0.9, 0.5), (0.95, y + 0.9, -0.2), "metal")
    u.part("stock", "box", (0.4, 0.5, 1.4), (0.75, t - 0.2, -0.2), "hull")
    z = gun(u, "rifle", 0.75, t - 0.1, -0.9, 4.6, 0.22)
    u.part("scope", "cylinder", (0.25, 0.25, 0.9), (0.75, t + 0.22, -1.1), "metal", axis="z")
    u.part("lens", "cylinder", (0.22, 0.22, 0.06), (0.75, t + 0.22, -1.58), "glass", axis="z")
    u.part("chestTeam", "box", (0.6, 0.4, 0.06), (-0.3, y + 0.8, -0.73), "team")
    u.attach("muzzle", "torso", (0.75, t - 0.1, z))
    out.append(u)

    u = U("ord_hush", ["Hush (Order jammer bot, T2): a small bot carrying a tall jammer mast on its back,", "three cross arms with glowing tips and an emitter dome. " + HEADER])
    y = biped(u, 2.1, 0.6, 0.5, 1.4, 1.2, team=True)
    t = torso(u, 1.6, 1.3, 1.4, y)
    head(u, t, -0.2, 0.75, 0.45, 0.7, "order")
    u.part("chestTeam", "box", (0.9, 0.45, 0.08), (0, y + 0.7, -0.73), "team")
    u.part("mast", "box", (0.25, 3.0, 0.25), (0, t + 1.5, 0.55), "metal")
    for i, w in enumerate((1.8, 1.4, 1.0)):
        yy = t + 1.0 + i * 0.85
        u.part(f"bar{i + 1}", "box", (w, 0.12, 0.12), (0, yy, 0.55), "dark")
        for s, n in ((-1, "L"), (1, "R")):
            u.part(f"tip{i + 1}{n}", "ball", (0.22, 0.22, 0.22), (s * w / 2, yy, 0.55), "glass")
    u.part("dome", "ball", (0.6, 0.6, 0.6), (0, t + 3.1, 0.55), "glass")
    out.append(u)

    u = U("ord_outrider", ["Outrider (Order fast raider bot, T2): long legs and a small body leaning", "forward, a fin on its back and a gun under each side. " + HEADER])
    y = biped(u, 2.9, 0.55, 0.45, 1.2, 1.1, team=True)
    u.part("torso", "box", (1.4, 1.0, 1.9), (0, y + 0.5, -0.2), "hull", parent="base", pivot=(0, y, 0), rot=(-8, 0, 0))
    u.part("nose", "wedge", (1.3, 0.8, 0.8), (0, y + 0.5, -1.5), "team")
    u.part("eye", "box", (0.8, 0.12, 0.06), (0, y + 0.75, -1.1), "glass")
    u.part("fin", "wedge", (0.12, 0.8, 1.2), (0, y + 1.4, 0.4), "team")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        z = gun(u, "gun" + n, s * 0.85, y + 0.25, -0.6, 1.2, 0.25, glow=True)
        u.attach(m, "torso", (s * 0.85, y + 0.25, z))
    out.append(u)

    u = U("ord_martyr", ["Martyr (Order amphibious rolling bomb, T2): no legs; a ball shell", "(`shell`, a client piece that rolls) with a team band, hazard stripes and", "glowing seams over a small sealed chassis. " + HEADER])
    u.part("base", "box", (1.2, 0.5, 1.2), (0, 0.4, 0), "dark", parent=None)
    u.part("shell", "ball", (2.6, 2.6, 2.6), (0, 1.35, 0), "hull", parent="base", anim=("spin", (1, 0, 0)), pivot=(0, 1.35, 0))
    u.part("band", "cylinder", (0.5, 2.72, 2.72), (0, 1.35, 0), "team", parent="shell", axis="x")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("hazard" + n, "cylinder", (0.15, 2.2, 2.2), (s * 0.85, 1.35, 0), "hazard", parent="shell", axis="x")
        u.part("cap" + n, "cylinder", (0.12, 0.8, 0.8), (s * 1.3, 1.35, 0), "glass", parent="shell", axis="x")
    u.visual.append("shell")
    u.attach("muzzle", "base", (0, 1.35, -1.4))  # the trigger weapon's; never fires
    out.append(u)

    u = U("ord_snare", ["Snare (Order all-terrain spider with an EMP laser, T2): a light body on four", "long legs with high knees and claw tips; an EMP emitter ring on its `torso`. " + HEADER])
    spider(u, 4, (1.5, 0.8, 2.0), 2.0, 0.8, 2.2, 3.4, 3.2, 0.28, team=True)
    u.part("torso", "box", (1.2, 0.7, 1.4), (0, 2.75, -0.1), "hull", parent="base", pivot=(0, 2.4, 0))
    u.part("emitter", "cylinder", (0.55, 0.55, 0.8), (0, 2.75, -1.1), "metal", axis="z")
    u.part("ring", "cylinder", (0.95, 0.95, 0.15), (0, 2.75, -1.45), "glass", axis="z")
    u.part("backTeam", "box", (1.0, 0.08, 0.9), (0, 3.12, 0.2), "team")
    u.attach("muzzle", "torso", (0, 2.75, -1.6))
    out.append(u)

    u = U("ord_stormcaller", ["Stormcaller (Order heavy assault bot, lightning rifle, T2): broad and armoured,", "big team shoulder pads, the lightning rifle as its right forearm with three", "glowing coils, a capacitor pack on its back. " + HEADER])
    y = biped(u, 2.9, 0.9, 0.75, 2.2, 1.7, team=True)
    t = torso(u, 2.7, 2.0, 2.2, y)
    u.part("chest", "wedge", (2.3, 1.2, 0.6), (0, y + 1.1, -1.35), "hull")
    head(u, t, -0.3, 1.0, 0.6, 0.9, "order")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("pad" + n, "box", (1.1, 0.7, 2.0), (s * 1.75, t - 0.1, 0), "team")
    u.part("rifle", "box", (0.8, 0.8, 3.0), (1.75, y + 0.4, -1.0), "hull")
    for i in range(3):
        u.part(f"coil{i + 1}", "cylinder", (1.0, 1.0, 0.18), (1.75, y + 0.4, -0.6 - i * 0.7), "glass", axis="z")
    u.part("prong", "box", (0.3, 0.3, 0.8), (1.75, y + 0.4, -2.85), "metal")
    u.part("armL", "box", (0.7, 1.4, 0.8), (-1.75, y + 0.5, -0.1), "metal")
    u.part("pack", "box", (1.8, 1.4, 0.8), (0, y + 1.1, 1.45), "dark")
    u.part("packGlow", "box", (1.2, 0.15, 0.06), (0, y + 1.5, 1.88), "glass")
    u.attach("muzzle", "torso", (1.75, y + 0.4, -3.35))
    out.append(u)

    u = U("ord_paragon", ["Paragon (Order amphibious assault mech, twin gauss cannons, T3): a sealed", "armoured body with float collars, a sensor head, and a long gauss cannon on", "each shoulder (`muzzle`, `muzzle2`). Laid out at bot size and scaled x1.7. " + HEADER], scale=1.7)
    y = biped(u, 2.9, 0.95, 0.75, 2.2, 1.7, team=True)
    t = torso(u, 2.6, 1.9, 2.3, y)
    u.part("bow", "wedge", (2.4, 1.2, 0.7), (0, y + 0.7, -1.45), "hull")
    head(u, t, -0.3, 1.0, 0.55, 0.9, "order")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("float" + n, "cylinder", (0.8, 0.8, 2.0), (s * 1.5, y - 0.35, 0), "team", parent="base", axis="z")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        u.part("mount" + n, "box", (0.9, 0.9, 1.6), (s * 1.75, t - 0.1, 0.1), "team")
        z = gun(u, "cannon" + n, s * 1.75, t - 0.1, -0.7, 2.8, 0.45)
        u.part("coil" + n, "cylinder", (0.65, 0.65, 0.18), (s * 1.75, t - 0.1, -1.3), "glass", axis="z")
        u.attach(m, "torso", (s * 1.75, t - 0.1, z))
    out.append(u)

    u = U("ord_champion", ["Champion (Order battle mech, rapid laser, T3): a heavy upright mech, a big", "chest with a team crest, a rotary laser cannon as the right arm and a tower", "shield on the left. Laid out at bot size and scaled x2.1. " + HEADER], scale=2.1)
    y = biped(u, 3.0, 1.0, 0.85, 2.4, 1.8, team=True)
    t = torso(u, 3.0, 2.2, 2.4, y)
    u.part("chest", "wedge", (2.6, 1.4, 0.7), (0, y + 1.2, -1.55), "team")
    head(u, t, -0.4, 1.1, 0.65, 1.0, "order")
    u.part("padR", "box", (1.2, 0.8, 2.2), (1.95, t - 0.1, 0), "team")
    u.part("armR", "box", (0.9, 1.6, 1.0), (2.0, y + 0.8, -0.2), "metal")
    u.part("laserBody", "cylinder", (1.2, 1.2, 2.2), (2.0, y + 0.1, -1.2), "hull", axis="z")
    for i, (dx, dy) in enumerate(((-0.28, 0.28), (0.28, 0.28), (-0.28, -0.28), (0.28, -0.28))):
        u.part(f"barrel{i + 1}", "cylinder", (0.3, 0.3, 1.4), (2.0 + dx, y + 0.1 + dy, -2.9), "metal", axis="z")
    u.part("lens", "cylinder", (1.0, 1.0, 0.1), (2.0, y + 0.1, -2.35), "glass", axis="z")
    u.part("padL", "box", (1.2, 0.8, 2.2), (-1.95, t - 0.1, 0), "team")
    u.part("shield", "box", (0.4, 2.6, 2.0), (-2.15, y + 0.4, -0.6), "hull")
    u.part("shieldTeam", "box", (0.06, 1.6, 1.2), (-2.38, y + 0.5, -0.6), "team")
    u.part("pack", "box", (2.2, 1.6, 0.9), (0, y + 1.2, 1.6), "dark")
    u.attach("muzzle", "torso", (2.0, y + 0.1, -3.7))
    out.append(u)

    u = U("ord_monolith", ["Monolith (Order all-terrain heavy plasma artillery, T3): a broad armoured", "body on four massive jointed legs with high knees and claw feet, a long heavy", "plasma cannon (`barrel`, pitches) on its turret (`torso`). Laid out at bot", "size and scaled x2.0. " + HEADER], scale=2.0)
    spider(u, 4, (2.6, 1.1, 3.0), 2.6, 1.2, 3.0, 4.0, 3.9, 0.5, team=True)
    u.part("skirt", "box", (2.8, 0.4, 3.2), (0, 2.0, 0), "dark", parent="base")
    u.part("torso", "box", (2.2, 1.0, 2.4), (0, 3.65, 0.3), "team", parent="base", pivot=(0, 3.15, 0.3))
    u.part("glacis", "wedge", (2.2, 0.8, 0.7), (0, 3.55, -1.25), "hull")
    u.part("barrel", "cylinder", (0.6, 0.6, 4.2), (0, 3.8, -2.4), "metal", axis="z", pivot=(0, 3.8, -0.3))
    u.part("sleeve", "cylinder", (0.85, 0.85, 1.2), (0, 3.8, -0.9), "hull", parent="barrel", axis="z")
    u.part("coil1", "cylinder", (0.8, 0.8, 0.15), (0, 3.8, -1.9), "glass", parent="barrel", axis="z")
    u.part("coil2", "cylinder", (0.8, 0.8, 0.15), (0, 3.8, -2.7), "glass", parent="barrel", axis="z")
    u.part("mouth", "cylinder", (0.8, 0.8, 0.4), (0, 3.8, -4.4), "dark", parent="barrel", axis="z")
    u.attach("muzzle", "barrel", (0, 3.8, -4.65))
    out.append(u)

    return out


# ---------------------------------------------------------------------------
# Chaos
# ---------------------------------------------------------------------------


def chaos():
    out = []

    u = U("chs_firebrand", ["Firebrand (Chaos rocket bot, T1): a hunched bot with an open rail rack over", "its right shoulder, rockets tipped amber, spikes on the left pad. " + HEADER])
    y = biped(u, 2.3, 0.8, 0.65, 2.0, 1.5, foot="metal", pelvis="dark")
    t = torso(u, 2.2, 1.5, 1.8, y, z=0.1)
    u.part("chestTeam", "box", (0.9, 0.5, 0.08), (-0.3, y + 0.7, -0.83), "team")
    u.part("head", "box", (0.8, 0.5, 0.8), (-0.35, t + 0.1, -0.5), "hull")
    u.part("slit", "box", (0.6, 0.12, 0.08), (-0.35, t + 0.15, -0.93), "glass")
    u.part("rack", "box", (1.3, 0.25, 2.2), (1.4, t + 0.35, 0.1), "metal", rot=(-12, 0, 0))
    for i in range(3):
        x = 1.0 + i * 0.4
        u.part(f"rocket{i + 1}", "cylinder", (0.28, 0.28, 1.8), (x, t + 0.6, 0.0), "dark", axis="z", rot=(-12, 0, 0))
        u.part(f"rocketTip{i + 1}", "cylinder", (0.3, 0.3, 0.15), (x, t + 0.79, -0.9), "glass", axis="z", rot=(-12, 0, 0))
    u.part("padL", "wedge", (1.0, 0.7, 1.8), (-1.45, t - 0.1, 0), "metal", rot=(0, 90, 0))
    spikes(u, (-1.65, -1.25), t + 0.25, 0.2)
    u.attach("muzzle", "torso", (1.4, t + 0.8, -1.05))
    out.append(u)

    u = U("chs_taskmaster", ["Taskmaster (Chaos advanced constructor bot, T2): a bulky worker with exhaust", "stacks, hazard-striped plates and a long crane arm (`nano`) ending in a claw. " + HEADER])
    y = biped(u, 2.6, 0.9, 0.75, 2.1, 1.6, foot="metal", pelvis="dark")
    t = torso(u, 2.6, 1.8, 2.2, y)
    u.part("head", "box", (0.9, 0.55, 0.8), (-0.6, t + 0.27, -0.5), "hull")
    u.part("slit", "box", (0.7, 0.12, 0.08), (-0.6, t + 0.32, -0.93), "glass")
    u.part("hazard", "box", (2.2, 0.3, 0.08), (0, y + 0.4, -1.13), "hazard")
    u.part("chestTeam", "box", (1.0, 0.5, 0.08), (0.4, y + 1.1, -1.13), "team")
    for i, x in enumerate((-0.7, -0.2)):
        u.part(f"stack{i + 1}", "cylinder", (0.35, 1.2, 0.35), (x, t + 0.5, 0.9), "dark", axis="y")
    u.part("boom", "box", (0.7, 0.7, 0.9), (1.3, t + 0.3, 0.4), "metal")
    nano_arm(u, 1.3, t + 0.5, 0.2, 3.4, "chaos", rise=0.8)
    out.append(u)

    u = U("chs_wrath", ["Wrath (Chaos heavy rocket artillery bot, T2): a squat bot hauling a big", "launcher box on its back (`launcher`, pitches up) with nine amber tubes. " + HEADER])
    y = biped(u, 2.5, 0.9, 0.75, 2.1, 1.6, foot="metal", pelvis="dark")
    t = torso(u, 2.4, 1.5, 2.0, y)
    u.part("head", "box", (0.9, 0.5, 0.8), (0, y + 1.0, -1.3), "hull")
    u.part("slit", "box", (0.7, 0.12, 0.08), (0, y + 1.05, -1.73), "glass")
    u.part("chestTeam", "box", (1.2, 0.4, 0.08), (0, y + 0.4, -1.03), "team")
    ly = t + 0.9
    u.part("launcher", "box", (2.6, 1.6, 2.2), (0, ly, 0.3), "hull", rot=(-20, 0, 0), pivot=(0, t, 0.8))
    u.part("frame", "box", (2.8, 0.2, 2.4), (0, t + 0.05, 0.4), "metal")
    for i in range(3):
        for j in range(3):
            x = (i - 1) * 0.75
            yy = ly + (j - 1) * 0.45 + 0.25
            u.part(f"tube{i + 1}{j + 1}", "cylinder", (0.4, 0.4, 0.12), (x, yy, -0.78 + (j - 1) * 0.16 + 0.1), "glass",
                   parent="launcher", axis="z", rot=(-20, 0, 0))
    spikes(u, (-1.15, 1.15), ly + 0.85, 0.6, parent="launcher")
    u.attach("muzzle", "launcher", (0, ly + 0.3, -0.95))
    out.append(u)

    u = U("chs_portent", ["Portent (Chaos radar bot, T2): spindly, with a lattice mast from its back", "carrying a spinning radar bar (`radar`) and an amber eye. " + HEADER])
    y = biped(u, 2.3, 0.6, 0.5, 1.4, 1.2, foot="metal", pelvis="dark")
    t = torso(u, 1.6, 1.2, 1.4, y)
    u.part("eye", "ball", (0.45, 0.45, 0.45), (0, y + 0.8, -0.72), "glass")
    u.part("chestTeam", "box", (0.8, 0.35, 0.08), (0, y + 0.35, -0.73), "team")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("leg" + n, "box", (0.12, 2.6, 0.12), (s * 0.3, t + 1.2, 0.6), "metal", rot=(0, 0, -s * 6))
    for i in range(3):
        u.part(f"rung{i + 1}", "box", (0.7 - i * 0.12, 0.08, 0.08), (0, t + 0.5 + i * 0.75, 0.6), "dark")
    radar(u, 0, t + 2.7, 0.6, 3.0, 0.6)
    spikes(u, (-0.6, 0.6), t, 0.2, h=0.5)
    out.append(u)

    u = U("chs_blister", ["Blister (Chaos amphibious crawling bomb, T2): a low tick on four short", "clawed legs, its swollen sac glowing through a cage of ribs, a hazard band. " + HEADER])
    spider(u, 4, (1.4, 0.7, 1.8), 1.0, 0.65, 1.35, 1.7, 1.8, 0.24, body_color="dark")
    u.part("sac", "ball", (1.7, 1.2, 1.9), (0, 1.55, 0.2), "glass", parent="base")
    for i, z in enumerate((-0.3, 0.2, 0.7)):
        u.part(f"rib{i + 1}", "box", (1.9, 0.15, 0.15), (0, 2.05, z), "metal", parent="base")
    u.part("hazard", "box", (1.5, 0.2, 0.08), (0, 1.0, -0.94), "hazard", parent="base")
    u.part("teamBand", "box", (1.5, 0.2, 0.08), (0, 1.0, 0.94), "team", parent="base")
    u.part("mandibleL", "wedge", (0.2, 0.3, 0.6), (-0.35, 0.8, -1.15), "metal", parent="base")
    u.part("mandibleR", "wedge", (0.2, 0.3, 0.6), (0.35, 0.8, -1.15), "metal", parent="base")
    u.attach("muzzle", "base", (0, 0.9, -1.3))  # the trigger weapon's; never fires
    out.append(u)

    u = U("chs_cutpurse", ["Cutpurse (Chaos stealthy jamming combat engineer, T2): lean and dark, a", "hooded head with one amber eye, cloak plates over the shoulders, twin whip", "antennas, a claw arm (`nano`) on the left and a short gun on the right. " + HEADER])
    y = biped(u, 2.6, 0.6, 0.5, 1.4, 1.2, color="dark", foot="metal", pelvis="dark")
    t = torso(u, 1.7, 1.4, 1.4, y, color="dark")
    u.part("hood", "wedge", (1.0, 0.7, 1.1), (0, t + 0.35, -0.1), "hull")
    u.part("eye", "ball", (0.3, 0.3, 0.3), (0, t + 0.25, -0.62), "glass")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("cloak" + n, "wedge", (0.6, 1.2, 1.5), (s * 1.0, t - 0.4, 0.1), "hull", rot=(0, 0, s * 15))
        u.part("whip" + n, "cylinder", (0.06, 2.2, 0.06), (s * 0.5, t + 1.1, 0.6), "metal", axis="y")
    nano_arm(u, -1.05, y + 0.5, -0.2, 1.6, "chaos")
    z = gun(u, "gun", 1.05, y + 0.5, -0.4, 1.0, 0.28)
    u.part("chestTeam", "box", (0.5, 0.35, 0.06), (0.3, y + 0.9, -0.73), "team")
    u.attach("muzzle", "torso", (1.05, y + 0.5, z))
    out.append(u)

    u = U("chs_gloom", ["Gloom (Chaos jammer bot, T2): a hunched little bot bristling with four", "spiked antenna spines on its back, amber tips, over a jammer dish. " + HEADER])
    y = biped(u, 2.0, 0.65, 0.55, 1.5, 1.2, foot="metal", pelvis="dark")
    t = torso(u, 1.8, 1.2, 1.6, y, z=0.1)
    u.part("head", "box", (0.8, 0.45, 0.7), (0, y + 0.9, -0.95), "hull")
    u.part("slit", "box", (0.6, 0.1, 0.06), (0, y + 0.95, -1.32), "glass")
    u.part("chestTeam", "box", (0.9, 0.35, 0.08), (0, y + 0.35, -0.73), "team")
    u.part("dish", "cylinder", (1.4, 0.2, 1.4), (0, t + 0.15, 0.3), "metal", axis="y")
    for i, (x, z, h, r) in enumerate(((-0.5, 0.0, 2.2, -15), (0.5, 0.0, 2.0, 15), (-0.3, 0.7, 1.6, -10), (0.35, 0.7, 1.8, 10))):
        u.part(f"spine{i + 1}", "box", (0.15, h, 0.15), (x, t + 0.25 + h / 2, z), "dark", rot=(0, 0, r))
        u.part(f"spineTip{i + 1}", "ball", (0.25, 0.25, 0.25), (x - 0.27 * (r / 15) * h / 2, t + 0.25 + h, z), "glass")
    out.append(u)

    u = U("chs_newt", ["Newt (Chaos amphibious bot, laser and torpedo, T2): squat and frog-wide on", "short legs, float pods on its flanks, bulging amber eyes, a laser on top", "(`muzzle`) and a torpedo tube under the chin (`muzzle2`). " + HEADER])
    y = biped(u, 1.8, 1.0, 0.7, 2.2, 1.6, foot="metal", pelvis="dark")
    t = torso(u, 2.6, 1.2, 2.4, y)
    u.part("jaw", "wedge", (2.4, 0.8, 0.8), (0, y + 0.4, -1.55), "hull")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("pod" + n, "cylinder", (0.9, 0.9, 2.2), (s * 1.6, y + 0.45, 0.1), "dark", axis="z")
        u.part("eye" + n, "ball", (0.45, 0.45, 0.45), (s * 0.7, t + 0.1, -1.0), "glass")
    u.part("chestTeam", "box", (1.2, 0.08, 0.8), (0, t + 0.04, 0.4), "team")
    u.part("laserMount", "box", (0.6, 0.4, 0.8), (0, t + 0.2, -0.1), "metal")
    z = gun(u, "laser", 0, t + 0.25, -0.5, 1.2, 0.3, glow=True)
    u.part("torpedo", "cylinder", (0.55, 0.55, 1.4), (0, y + 0.1, -1.4), "metal", axis="z")
    u.attach("muzzle", "torso", (0, t + 0.25, z))
    u.attach("muzzle2", "torso", (0, y + 0.1, -2.15))
    out.append(u)

    u = U("chs_pyre", ["Pyre (Chaos fast flamethrower bot, T2): lean and forward-leaning, two hazard", "fuel tanks on its back, a flamer nozzle as the right arm with an amber pilot", "light. " + HEADER])
    y = biped(u, 2.6, 0.6, 0.5, 1.4, 1.2, foot="metal", pelvis="dark")
    u.part("torso", "box", (1.7, 1.3, 1.5), (0, y + 0.65, -0.15), "hull", parent="base", pivot=(0, y, 0), rot=(-10, 0, 0))
    u.part("head", "box", (0.7, 0.45, 0.7), (-0.3, y + 1.45, -0.6), "hull")
    u.part("slit", "box", (0.5, 0.1, 0.06), (-0.3, y + 1.5, -0.97), "glass")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("tank" + n, "cylinder", (0.55, 1.4, 0.55), (s * 0.35, y + 0.9, 0.9), "hazard", axis="y")
    u.part("hose", "box", (0.15, 0.15, 1.2), (0.7, y + 0.5, 0.3), "dark")
    u.part("arm", "box", (0.55, 0.55, 1.2), (1.05, y + 0.5, -0.5), "metal")
    z = gun(u, "nozzle", 1.05, y + 0.5, -1.1, 0.9, 0.4, color="dark", glow=True)
    spikes(u, (-0.7,), y + 1.2, 0.0, h=0.5)
    u.part("chestTeam", "box", (0.5, 0.35, 0.06), (-0.4, y + 0.6, -0.92), "team")
    u.attach("muzzle", "torso", (1.05, y + 0.5, z))
    out.append(u)

    u = U("chs_gargoyle", ["Gargoyle (Chaos heavy amphibious anti-air bot, T2): big and hunched on thick", "legs, two tall missile racks on the shoulders like folded wings (`launcher`,", "pitches), horns, amber cells. " + HEADER])
    y = biped(u, 2.6, 1.0, 0.8, 2.3, 1.8, foot="metal", pelvis="dark")
    t = torso(u, 2.8, 1.8, 2.4, y, z=0.1)
    u.part("head", "box", (1.0, 0.6, 0.9), (0, y + 1.3, -1.4), "hull")
    u.part("slit", "box", (0.8, 0.12, 0.06), (0, y + 1.35, -1.87), "glass")
    spikes(u, (-0.45, 0.45), y + 1.6, -1.3, h=0.6, w=0.2)
    u.part("chestTeam", "box", (1.4, 0.5, 0.08), (0, y + 0.5, -1.13), "team")
    py = t + 0.2
    u.part("launcher", "box", (0.8, 0.4, 0.8), (0, py, 0.4), "metal", pivot=(0, py, 0.4))
    for s, n in ((-1, "L"), (1, "R")):
        u.part("rack" + n, "wedge", (1.1, 2.4, 1.6), (s * 1.75, py + 0.8, 0.4), "hull", parent="launcher")
        tubes(u, "cell" + n, s * 1.75, py + 0.4, -0.45, 2, 3, 0.42, 0.3, "launcher")
    u.attach("muzzle", "launcher", (1.75, py + 0.8, -0.65))
    out.append(u)

    u = U("chs_spitter", ["Spitter (Chaos mortar bot, T2): squat and low on thick legs, a fat mortar", "tube (`barrel`, pitches) on its back beside an ammo drum. " + HEADER])
    y = biped(u, 2.0, 0.9, 0.75, 2.0, 1.6, foot="metal", pelvis="dark")
    t = torso(u, 2.3, 1.3, 2.1, y)
    u.part("head", "box", (0.8, 0.45, 0.7), (0, y + 0.8, -1.3), "hull")
    u.part("slit", "box", (0.6, 0.1, 0.06), (0, y + 0.85, -1.67), "glass")
    u.part("chestTeam", "box", (1.2, 0.4, 0.08), (0, y + 0.3, -1.08), "team")
    u.part("drum", "cylinder", (1.0, 0.9, 1.0), (-0.75, t + 0.45, 0.5), "dark", axis="x")
    py = t + 0.3
    u.part("cradle", "box", (1.0, 0.6, 1.0), (0.5, py, 0.5), "metal")
    u.part("barrel", "cylinder", (0.95, 0.95, 1.9), (0.5, py + 0.7, -0.1), "metal", axis="z", rot=(50, 0, 0), pivot=(0.5, py, 0.5))
    u.part("mouthRing", "cylinder", (1.05, 1.05, 0.2), (0.5, py + 1.35, -0.65), "glass", parent="barrel", axis="z", rot=(50, 0, 0))
    spikes(u, (-1.0, 1.0), t - 0.1, -0.6, h=0.5)
    u.attach("muzzle", "barrel", (0.5, py + 1.45, -0.75))
    out.append(u)

    u = U("chs_pustule", ["Pustule (Chaos cloaked amphibious crawling bomb, big blast, T2): a fat tick on", "four clawed legs, a huge glowing sac caged in metal ribs, dark plates. " + HEADER])
    spider(u, 4, (1.8, 0.8, 2.2), 1.2, 0.85, 1.75, 2.2, 2.4, 0.3, body_color="dark", color="dark")
    u.part("sac", "ball", (2.4, 1.8, 2.6), (0, 2.0, 0.3), "glass", parent="base")
    for i, z in enumerate((-0.5, 0.2, 0.9)):
        u.part(f"rib{i + 1}", "box", (2.6, 0.18, 0.18), (0, 2.75, z), "metal", parent="base")
    u.part("spine", "box", (0.2, 0.2, 2.4), (0, 2.95, 0.3), "metal", parent="base")
    u.part("hazard", "box", (1.9, 0.25, 0.08), (0, 1.2, -1.14), "hazard", parent="base")
    u.part("teamBand", "box", (1.9, 0.25, 0.08), (0, 1.2, 1.14), "team", parent="base")
    u.attach("muzzle", "base", (0, 1.2, -1.3))  # the trigger weapon's; never fires
    out.append(u)

    u = U("chs_snitch", ["Snitch (Chaos cloaked spy bot, T2): tiny and crouched, dark plates, one amber", "eye, a whip antenna and the EMP charge glowing in its back. " + HEADER])
    y = biped(u, 1.5, 0.45, 0.35, 1.0, 0.9, color="dark", foot="metal", pelvis="dark")
    t = torso(u, 1.2, 0.9, 1.4, y, color="dark")
    u.part("head", "wedge", (0.8, 0.5, 0.8), (0, t + 0.2, -0.4), "hull")
    u.part("eye", "ball", (0.3, 0.3, 0.3), (0, t + 0.1, -0.82), "glass")
    u.part("whip", "cylinder", (0.06, 1.8, 0.06), (0.3, t + 0.9, 0.5), "metal", axis="y")
    u.part("core", "cylinder", (0.55, 0.55, 0.12), (0, y + 0.45, 0.76), "glass", axis="z")
    u.part("teamFin", "box", (0.08, 0.3, 0.6), (-0.3, t + 0.15, 0.3), "team")
    u.attach("muzzle", "torso", (0, t + 0.1, -0.95))
    out.append(u)

    u = U("chs_ravener", ["Ravener (Chaos heavy all-terrain spider, heat ray, T2): a heavy armoured body", "on four thick jointed legs with high knees and claws, a turret (`torso`) with", "a heat-ray projector and an amber lens. " + HEADER])
    spider(u, 4, (2.2, 1.0, 2.8), 2.2, 1.0, 2.8, 3.8, 3.8, 0.42, body_color="dark")
    u.part("plate", "wedge", (2.0, 0.7, 0.8), (0, 2.2, -1.75), "hull", parent="base")
    spikes(u, (-0.7, 0.0, 0.7), 2.7, 1.1, parent="base", prefix="backSpike", h=0.6)
    u.part("torso", "box", (1.7, 0.9, 1.8), (0, 3.15, -0.1), "hull", parent="base", pivot=(0, 2.7, 0))
    u.part("chestTeam", "box", (1.1, 0.08, 0.8), (0, 3.62, 0.2), "team")
    u.part("projector", "cylinder", (0.8, 0.8, 1.4), (0, 3.15, -1.5), "metal", axis="z")
    u.part("lens", "cylinder", (0.95, 0.95, 0.15), (0, 3.15, -2.25), "glass", axis="z")
    u.attach("muzzle", "torso", (0, 3.15, -2.4))
    out.append(u)

    u = U("chs_scrounger", ["Scrounger (Chaos combat engineer bot, T2): wiry and quick, a scrap hopper on", "its back, a claw arm (`nano`) on the right and a short gun on the left. " + HEADER])
    y = biped(u, 2.4, 0.6, 0.5, 1.4, 1.2, foot="metal", pelvis="dark")
    t = torso(u, 1.7, 1.3, 1.5, y)
    u.part("head", "box", (0.75, 0.45, 0.7), (-0.2, t + 0.22, -0.4), "hull")
    u.part("slit", "box", (0.55, 0.1, 0.06), (-0.2, t + 0.27, -0.77), "glass")
    u.part("hopper", "wedge", (1.6, 1.0, 1.0), (0, t + 0.2, 0.75), "metal", rot=(0, 180, 0))
    u.part("scrap", "box", (1.2, 0.3, 0.6), (0, t + 0.55, 0.85), "dark", rot=(0, 15, 8))
    nano_arm(u, 1.05, y + 0.6, -0.1, 1.6, "chaos")
    z = gun(u, "gun", -1.05, y + 0.5, -0.4, 1.0, 0.28)
    u.part("chestTeam", "box", (0.6, 0.35, 0.06), (0.2, y + 0.6, -0.78), "team")
    u.attach("muzzle", "torso", (-1.05, y + 0.5, z))
    out.append(u)

    u = U("chs_colossus", ["Colossus (Chaos barely mobile walking fortress, three lasers, T3): a massive", "block of armour on four stubby trunk legs (client pieces `legFL` .. `legBR`,", "swinging at the hip like the Mammoth's), crowned by three laser turrets: a big", "one on the `torso` and one at each front corner (`muzzle` .. `muzzle3`). Laid out", "half size and scaled x2. " + HEADER], scale=2.0)
    u.part("base", "box", (8.0, 4.0, 8.0), (0, 5.0, 0), "hull", parent=None)
    for tag, x, z in (("FL", -3.2, -3.0), ("FR", 3.2, -3.0), ("BL", -3.2, 3.0), ("BR", 3.2, 3.0)):
        u.part("leg" + tag, "box", (2.2, 3.4, 2.2), (x, 1.7, z), "dark", parent="base", anim=("swing", (1, 0, 0)), pivot=(x, 3.2, z))
        u.part("foot" + tag, "box", (2.8, 0.6, 2.8), (x, 0.3, z), "metal", parent="leg" + tag)
        u.visual.append("leg" + tag)
    u.part("skirt", "box", (8.6, 0.8, 8.6), (0, 3.2, 0), "dark", parent="base")
    u.part("glacis", "wedge", (8.0, 2.0, 1.6), (0, 4.2, -4.8), "hull", parent="base")
    u.part("teamL", "box", (0.08, 1.4, 5.0), (-4.04, 5.2, 0.5), "team", parent="base")
    u.part("teamR", "box", (0.08, 1.4, 5.0), (4.04, 5.2, 0.5), "team", parent="base")
    for i, (x, z) in enumerate(((-3.0, 2.8), (3.0, 2.8), (-3.0, -0.5), (3.0, -0.5))):
        u.part(f"spike{i + 1}", "wedge", (0.6, 1.4, 0.9), (x, 7.7, z), "metal", parent="base")
    u.part("torso", "box", (3.6, 1.8, 3.6), (0, 7.9, 0.6), "hull", parent="base", pivot=(0, 7.0, 0.6))
    u.part("turretTeam", "box", (2.4, 0.08, 1.6), (0, 8.82, 1.2), "team")
    z = gun(u, "laser", 0, 8.0, -1.2, 3.2, 0.9, color="dark", glow=True)
    u.attach("muzzle", "torso", (0, 8.0, z))
    for s, n, m in ((-1, "L", "muzzle2"), (1, "R", "muzzle3")):
        u.part("pod" + n, "box", (1.6, 1.2, 1.8), (s * 2.9, 7.6, -2.6), "dark", parent="base")
        z = gun(u, "podLaser" + n, s * 2.9, 7.6, -3.5, 1.4, 0.55, color="metal", parent="base", glow=True)
        u.attach(m, "base", (s * 2.9, 7.6, z))
    out.append(u)

    u = U("chs_pandemonium", ["Pandemonium (Chaos heavy rocket mech, T3): a stooped mech with a massive", "rocket box on each shoulder, nine amber tubes each, a small armoured head and", "spikes. Laid out at bot size and scaled x2.0. " + HEADER], scale=2.0)
    y = biped(u, 2.8, 1.0, 0.85, 2.3, 1.8, foot="metal", pelvis="dark")
    t = torso(u, 2.6, 1.9, 2.2, y, z=0.1)
    u.part("head", "box", (0.9, 0.55, 0.8), (0, y + 1.4, -1.35), "hull")
    u.part("slit", "box", (0.7, 0.12, 0.06), (0, y + 1.45, -1.77), "glass")
    u.part("chestTeam", "box", (1.2, 0.5, 0.08), (0, y + 0.6, -1.03), "team")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        u.part("box" + n, "box", (1.8, 1.8, 2.4), (s * 2.25, t + 0.3, 0.1), "hull")
        u.part("boxTeam" + n, "box", (0.06, 1.0, 1.6), (s * 3.17, t + 0.3, 0.2), "team")
        tubes(u, "tube" + n, s * 2.25, t + 0.3, -1.12, 3, 3, 0.5, 0.36, "torso")
        spikes(u, (s * 2.25,), t + 1.2, 0.4, prefix="spike" + n)
        u.attach(m, "torso", (s * 2.25, t + 0.3, -1.3))
    out.append(u)

    u = U("chs_infernal", ["Infernal (Chaos flamethrower mech with anti-air shoulder rockets, T3): a horned", "heavy mech, a flamer cannon as each forearm (`muzzle`, `muzzle2`), fuel tanks", "on its back and a rocket pod on each shoulder raked skyward (`aa_muzzle`).", "Laid out at bot size and scaled x2.2. " + HEADER], scale=2.2)
    y = biped(u, 3.0, 1.0, 0.9, 2.4, 1.8, foot="metal", pelvis="dark")
    t = torso(u, 2.8, 2.1, 2.3, y)
    u.part("head", "box", (1.0, 0.65, 0.9), (0, t + 0.3, -0.6), "hull")
    u.part("slit", "box", (0.8, 0.12, 0.06), (0, t + 0.38, -1.08), "glass")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("horn" + n, "wedge", (0.25, 1.0, 0.7), (s * 0.55, t + 1.0, -0.5), "metal", rot=(0, 0, -s * 20))
        u.part("tank" + n, "cylinder", (0.7, 1.6, 0.7), (s * 0.55, y + 1.1, 1.45), "hazard", axis="y")
    u.part("chestTeam", "box", (1.4, 0.5, 0.08), (0, y + 0.8, -1.18), "team")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        u.part("arm" + n, "box", (0.9, 1.6, 1.0), (s * 1.95, y + 0.9, -0.1), "metal")
        z = gun(u, "flamer" + n, s * 1.95, y + 0.2, -0.6, 1.8, 0.7, color="dark", glow=True)
        u.attach(m, "torso", (s * 1.95, y + 0.2, z))
        u.part("pod" + n, "box", (1.0, 0.9, 1.4), (s * 1.75, t + 0.35, 0.2), "hull", rot=(25, 0, 0))
        u.part("podCells" + n, "box", (0.8, 0.08, 0.7), (s * 1.75, t + 0.72, -0.1), "glass", rot=(25, 0, 0))
    u.attach("aa_muzzle", "torso", (1.75, t + 0.9, -0.3))
    out.append(u)

    u = U("chs_widowmaker", ["Widowmaker (Chaos all-terrain assault spider mech, missiles, T3): an armoured", "body on six long jointed legs with high knees and claws, a raised cockpit", "turret (`torso`) with an amber eye slit and a missile pod on each side.", "Laid out at bot size and scaled x1.8. " + HEADER], scale=1.8)
    spider(u, 6, (2.4, 1.1, 3.2), 2.4, 1.1, 2.9, 4.1, 4.0, 0.4, body_color="dark")
    u.part("abdomen", "box", (2.0, 1.2, 1.6), (0, 2.6, 2.1), "hull", parent="base")
    u.part("abdomenGlow", "box", (1.4, 0.1, 1.0), (0, 3.22, 2.1), "glass", parent="base")
    spikes(u, (-0.6, 0.6), 3.2, 2.5, parent="base", prefix="backSpike")
    u.part("torso", "box", (1.8, 1.1, 1.8), (0, 3.5, -0.4), "hull", parent="base", pivot=(0, 2.95, -0.2))
    u.part("slit", "box", (1.2, 0.15, 0.06), (0, 3.7, -1.33), "glass")
    u.part("chestTeam", "box", (1.0, 0.08, 0.8), (0, 4.07, -0.2), "team")
    for s, n, m in ((1, "R", "muzzle"), (-1, "L", "muzzle2")):
        u.part("pod" + n, "box", (0.8, 0.8, 1.4), (s * 1.3, 3.5, -0.5), "metal")
        tubes(u, "cell" + n, s * 1.3, 3.5, -1.22, 2, 2, 0.34, 0.26, "torso")
        u.attach(m, "torso", (s * 1.3, 3.5, -1.35))
    out.append(u)

    u = U("chs_abyssal", ["Abyssal (Chaos amphibious siege mech, heavy cannon, T3): a sealed, rounded hulk", "with ballast tanks on its back and a single huge cannon on the right", "shoulder. Laid out at bot size and scaled x1.8. " + HEADER], scale=1.8)
    y = biped(u, 2.8, 1.0, 0.85, 2.3, 1.8, foot="metal", pelvis="dark")
    t = torso(u, 2.6, 2.0, 2.4, y)
    u.part("dome", "ball", (2.4, 1.2, 2.2), (0, t, 0), "hull")
    u.part("slit", "box", (1.0, 0.15, 0.06), (-0.3, y + 1.45, -1.23), "glass")
    u.part("chestTeam", "box", (1.2, 0.5, 0.08), (-0.3, y + 0.7, -1.23), "team")
    for s, n in ((-1, "L"), (1, "R")):
        u.part("ballast" + n, "cylinder", (0.8, 2.0, 0.8), (s * 0.6, y + 1.1, 1.5), "dark", axis="y")
    u.part("armL", "box", (0.9, 1.5, 1.0), (-1.75, y + 0.7, -0.1), "metal")
    u.part("claw", "wedge", (0.6, 0.7, 0.9), (-1.75, y - 0.2, -0.5), "dark")
    u.part("mount", "box", (1.2, 1.2, 2.0), (1.85, t - 0.2, 0.2), "hull")
    z = gun(u, "cannon", 1.85, t - 0.2, -0.8, 3.6, 0.8)
    u.part("sleeve", "cylinder", (1.05, 1.05, 1.0), (1.85, t - 0.2, -1.3), "dark", axis="z")
    u.attach("muzzle", "torso", (1.85, t - 0.2, z))
    out.append(u)

    return out


if __name__ == "__main__":
    units = order() + chaos()
    for u in units:
        u.parts = [p for p in u.parts if p]
        u.fit(PIECES.get(u.uid))
        u.write()
    print(f"{len(units)} blockouts written")
