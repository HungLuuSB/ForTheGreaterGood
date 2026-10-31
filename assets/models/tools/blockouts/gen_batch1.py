"""Writes the hand-made blockouts of the BAR roster's batch 1 (vehicles and
hovercraft, the user's approval 2026-10-31; sim-A's list in docs/progress/sim.md
"For the models stream (C)" item 3):

    python gen_batch1.py <src/shared/Defs/Blockouts> [pieces.json]

pieces.json ({id: [piece, ...]}, dumped from the defs, S-230) fits each rig to
its def: only def pieces pivot, decorations hang from their nearest piece.

Silhouettes from the roles, ahead of the defs (footprints and pieces come
with S-228+): the files are written but not registered in Blockouts/Registry
until each def exists. Our own designs: BAR's pictures and models are looked
at only (CC BY-NC-ND). Pieces follow ours: `base`, a yawing `turret`, a
pitching `barrel` (or `launcher`), a `nano` arm on constructors, scrolling
`trackL` / `trackR`; muzzles, `nano1` and factory `buildpad` attachments.
Order reads clean and heavy (skirts, sloped plates); Chaos angular and open
(exposed frames, spikes). Hovercraft ride a skirt (`skirt`, dark) with lift
fans; amphibious hulls carry a boat bow and flotation sponsons.
Model space, forward = -Z, ground at y = 0.
"""
import json
import os
import sys

OUT = sys.argv[1]


def f(v):
    return f"{round(v, 3):g}"


def vec(v):
    return "{ " + ", ".join(f(x) for x in v) + " }"


class B:
    def __init__(self, uid, comment):
        self.uid, self.comment, self.parts, self.att, self.visual = uid, comment, [], [], []

    def part(self, name, shape, size, at, color, parent="base", rot=None, axis=None, pivot=None, anim=None):
        self.parts.append(dict(name=name, shape=shape, size=size, at=at, color=color, parent=parent, rot=rot,
                               axis=axis, pivot=pivot, anim=anim))

    def attach(self, name, parent, at):
        self.att.append(dict(name=name, parent=parent, at=at))

    def fit(self, pieces):
        """Matches the def's pieces (Blockout.validate): only pieces pivot, a
        decoration's children hang from its nearest piece, and a def piece
        named as an attachment here becomes a marker part instead."""
        if pieces is None:
            return
        parent = {p["name"]: p["parent"] for p in self.parts}

        def piece_of(name):
            while name != "base" and name not in pieces:
                name = parent[name]
            return name

        for p in self.parts:
            if p["name"] != "base":
                p["parent"] = piece_of(p["parent"])
            if p["pivot"] and p["name"] not in pieces:
                p["pivot"] = None
        names = {p["name"] for p in self.parts}
        for a in list(self.att):
            a["parent"] = piece_of(a["parent"])
            muzzle = a["name"].startswith("muzzle") or "_muzzle" in a["name"]
            if a["name"] in pieces and not muzzle:
                self.att.remove(a)
                if a["name"] not in names:
                    self.part(a["name"], "ball", (0.3, 0.3, 0.3), a["at"], "dark", parent=a["parent"])

    def write(self):
        lines = ["--!strict"] + [f"-- {c}" if c else "--" for c in self.comment] + ["", "return {", f'\tid = "{self.uid}",']
        if self.visual:
            lines.append("\tvisualPieces = { " + ", ".join(f'"{v}"' for v in self.visual) + " },")
        lines.append("\tparts = {")
        for p in self.parts:
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
            lines.append(f"\t\t{s} }},")
        lines.append("\t},")
        if self.att:
            lines.append("\tattachments = {")
            lines += [f'\t\t{{ name = "{a["name"]}", parent = "{a["parent"]}", at = {vec(a["at"])} }},' for a in self.att]
            lines.append("\t},")
        lines.append("}")
        with open(os.path.join(OUT, f"{self.uid}.luau"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")


HEADER = "Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def."


# ---------------------------------------------------------------------------
# kits
# ---------------------------------------------------------------------------


def tracked(b, L, W, H, faction, tw=None):
    """Tracked hull; returns the deck height."""
    tw = tw or max(0.9, W * 0.2)
    deck = 0.5 + H
    b.part("base", "box", (W - 2 * tw + 0.2, H, L), (0, 0.5 + H / 2, 0), "hull")
    b.part("glacis", "wedge", (W - 2 * tw + 0.2, H * 0.8, L * 0.18), (0, 0.5 + H * 0.6, -L * 0.59), "hull")
    for s, n in ((-1, "trackL"), (1, "trackR")):
        b.part(n, "box", (tw, 1.1 + H * 0.2, L * 1.04), (s * (W / 2 - tw / 2), (1.1 + H * 0.2) / 2, 0), "track",
               anim=("scroll", (1, 0, 0)))
        if faction == "order":
            b.part("skirt" + n[-1], "box", (0.25, H * 0.7, L * 0.9), (s * (W / 2 + 0.12), 0.5 + H * 0.55, 0), "hull")
        else:
            b.part("cage" + n[-1], "box", (0.12, 0.12, L * 0.85), (s * (W / 2 + 0.06), 0.4 + H * 0.75, 0), "metal")
    return deck


def amphib(b, L, W, H, faction):
    """Amphibious hull: tracks, a boat bow and flotation sponsons; returns the deck."""
    deck = tracked(b, L, W, H, faction)
    b.part("bow", "wedge", (W - 0.4, H * 1.1, L * 0.3), (0, 0.6 + H * 0.5, -L * 0.62), "hull")
    for s in (-1, 1):
        b.part("float" + ("L" if s < 0 else "R"), "cylinder", (0.9, 0.9, L * 0.7), (s * (W / 2 + 0.35), 0.6 + H * 0.6, 0.2),
               "team" if faction == "order" else "dark", axis="z")
    b.part("snorkel", "cylinder", (0.35, 1.6, 0.35), (W * 0.3, deck + 0.8, L * 0.38), "metal", axis="y")
    return deck


def hover(b, L, W, H, faction, fans=2):
    """Hovercraft: a dark skirt, a hull on it and lift fans at the back; returns the deck."""
    b.part("base", "box", (W, 0.8, L), (0, 0.4, 0), "dark")  # the skirt
    b.part("bowSkirt", "wedge", (W, 0.8, L * 0.2), (0, 0.4, -L * 0.6), "dark")
    hull_w, hull_h = W * 0.82, H
    b.part("hull", "box", (hull_w, hull_h, L * 0.85), (0, 0.8 + hull_h / 2, 0.1), "hull")
    b.part("prow", "wedge", (hull_w, hull_h, L * 0.22), (0, 0.8 + hull_h / 2, -L * 0.53), "hull")
    deck = 0.8 + hull_h
    for i in range(fans):
        x = 0 if fans == 1 else (-1 + 2 * i / (fans - 1)) * W * 0.28
        b.part(f"fan{i + 1}", "cylinder", (W * 0.3, 0.3, W * 0.3), (x, deck + 0.15, L * 0.33), "metal", axis="y")
        b.part(f"fanGuard{i + 1}", "cylinder", (W * 0.34, 0.12, W * 0.34), (x, deck + 0.34, L * 0.33), "dark", axis="y")
    if faction == "order":
        b.part("stripe", "box", (hull_w * 0.5, 0.06, L * 0.3), (0, deck + 0.03, -L * 0.12), "team")
    else:
        for s in (-1, 1):
            b.part("rail" + ("L" if s < 0 else "R"), "box", (0.15, 0.4, L * 0.8), (s * W * 0.5, 1.0, 0), "metal")
    return deck


def turret_gun(b, deck, z, tw, th, tl, bore, blen, team=True, faction="order", y_off=0.0):
    """A yawing turret and a pitching barrel; adds `muzzle`."""
    ty = deck + th / 2 + y_off
    b.part("turret", "box", (tw, th, tl), (0, ty, z), "team" if team else "hull")
    if faction == "order":
        b.part("turretFront", "wedge", (tw, th, tl * 0.3), (0, ty, z - tl * 0.65), "team" if team else "hull", parent="turret")
    else:
        b.part("turretSpike", "wedge", (tw * 0.5, th * 0.6, tl * 0.4), (0, ty + th * 0.6, z - tl * 0.2), "dark", parent="turret")
    pz = z - tl / 2
    b.part("barrel", "cylinder", (bore, bore, blen), (0, ty, pz - blen / 2), "metal", parent="turret", axis="z", pivot=(0, ty, pz))
    b.attach("muzzle", "barrel", (0, ty, pz - blen))
    return ty


def nano_arm(b, deck, x, z, faction, length=3.0):
    """Constructor arm: a yawing `nano` turret with a boom; adds `nano1`."""
    b.part("nano", "cylinder", (1.4, 0.5, 1.4), (x, deck + 0.25, z), "dark", axis="y")
    b.part("boom", "box", (0.5, 0.5, length), (x, deck + 1.0, z - length / 2), "team" if faction == "order" else "hull",
           parent="nano", rot=(-20, 0, 0))
    b.part("emitter", "ball", (0.7, 0.7, 0.7), (x, deck + 1.55, z - length), "glass", parent="nano")
    b.attach("nano1", "nano", (x, deck + 1.55, z - length - 0.3))


def rocket_rack(b, deck, z, w, h, l, tubes, faction, name="launcher"):
    """A yawing turret with a pitching rocket box; adds `muzzle`."""
    b.part("turret", "cylinder", (w * 0.7, 0.5, w * 0.7), (0, deck + 0.25, z), "dark", axis="y")
    y = deck + 0.5 + h / 2
    b.part(name, "box", (w, h, l), (0, y, z), "team" if faction == "order" else "hull", parent="turret",
           pivot=(0, y, z + l * 0.3))
    for i in range(tubes):
        x = (-0.5 + (i + 0.5) / tubes) * w * 0.8
        b.part(f"tube{i + 1}", "cylinder", (w * 0.6 / tubes, w * 0.6 / tubes, 0.1), (x, y, z - l / 2 - 0.05), "glass",
               parent=name, axis="z")
    b.attach("muzzle", name, (0, y, z - l / 2 - 0.2))


def coil(b, x, y, z, h, r, parent, n):
    b.part(f"coil{n}", "cylinder", (r, h, r), (x, y + h / 2, z), "metal", parent=parent, axis="y")
    for i in range(3):
        b.part(f"coil{n}Ring{i + 1}", "cylinder", (r * 1.6, 0.15, r * 1.6), (x, y + h * (0.3 + 0.25 * i), z), "glass",
               parent=parent, axis="y")
    b.part(f"coil{n}Top", "ball", (r * 1.8, r * 1.8, r * 1.8), (x, y + h + r * 0.6, z), "glass", parent=parent)


def factory(b, faction, size):
    """Hover factory on land or water: a deck on pontoons, a covered bay, cranes,
    a slipway ramp at the front; adds `buildpad` and `nano1..3`."""
    h = size / 2
    b.part("base", "box", (size, 1.0, size), (0, 0.5, 0), "dark")
    for s in (-1, 1):
        b.part("pontoon" + ("L" if s < 0 else "R"), "box", (2.2, 1.6, size), (s * (h - 1.1), 0.8, 0), "hull")
    b.part("ramp", "wedge", (size * 0.5, 0.9, 3.0), (0, 0.45, -h - 1.5), "metal")
    b.part("bay", "box", (size * 0.62, 6.0, size * 0.38), (0, 4.0, h * 0.55), "hull")
    b.part("bayRoof", "box", (size * 0.66, 0.5, size * 0.42), (0, 7.2, h * 0.55), "team" if faction == "order" else "dark")
    for i, x in enumerate((-h * 0.62, h * 0.62, 0)):
        top = 6.4 if i < 2 else 7.6
        b.part(f"crane{i + 1}", "box", (0.8, top, 0.8), (x, top / 2 + 1, -h * 0.1 if i < 2 else h * 0.12), "metal")
        b.attach(f"nano{i + 1}", "base", (x, top + 1.2, -h * 0.25 if i < 2 else h * 0.02))
    b.part("pad", "box", (size * 0.48, 0.12, size * 0.48), (0, 1.06, -h * 0.2), "team" if faction == "order" else "hazard")
    if faction == "chaos":
        for s in (-1, 1):
            b.part("spike" + ("L" if s < 0 else "R"), "wedge", (0.6, 3.0, 1.2), (s * h * 0.95, 2.5, -h * 0.9), "metal")
    b.attach("buildpad", "base", (0, 1.1, -h * 0.2))


# ---------------------------------------------------------------------------
# the units
# ---------------------------------------------------------------------------


def make_all():
    out = []

    # --- Order ---
    b = B("ord_courser", ["Courser (Order fast light assault tank, T1): a low, narrow wedge on light tracks,", "a small flat turret and a short quick gun. " + HEADER])
    d = tracked(b, 6.4, 4.2, 0.9, "order")
    turret_gun(b, d, 0.4, 2.4, 0.8, 2.6, 0.32, 3.2)
    out.append(b)

    b = B("ord_gemini", ["Gemini (Order twin rocket-launcher tank, T1): a tracked hull with a turret", "carrying two rocket boxes side by side (the `launcher` pitches). " + HEADER])
    d = tracked(b, 7.0, 4.8, 1.0, "order")
    b.part("turret", "box", (3.0, 0.8, 3.0), (0, d + 0.4, 0.4), "hull")
    y = d + 1.4
    b.part("launcher", "box", (0.6, 0.6, 0.6), (0, y, 0.4), "dark", parent="turret", pivot=(0, y, 0.6))
    for s in (-1, 1):
        n = "L" if s < 0 else "R"
        b.part("pod" + n, "box", (1.3, 1.1, 2.8), (s * 1.0, y, 0.2), "team", parent="launcher")
        b.part("pod" + n + "Face", "box", (1.0, 0.8, 0.1), (s * 1.0, y, -1.25), "glass", parent="launcher")
    b.attach("muzzle", "launcher", (-1.0, y, -1.4))
    b.attach("muzzle2", "launcher", (1.0, y, -1.4))
    out.append(b)

    b = B("ord_wader", ["Wader (Order light amphibious tank, T1): a boat-bowed tracked hull with", "flotation sponsons and a snorkel, a small turret and gun. " + HEADER])
    d = amphib(b, 6.8, 4.6, 1.1, "order")
    turret_gun(b, d, 0.6, 2.4, 0.8, 2.4, 0.3, 2.8)
    out.append(b)

    b = B("ord_pontifex", ["Pontifex (Order amphibious constructor, T1): the amphibious hull with a", "cab and a constructor arm (`nano`). " + HEADER])
    d = amphib(b, 7.0, 4.8, 1.1, "order")
    b.part("cab", "box", (2.0, 1.2, 1.8), (-1.0, d + 0.6, -1.6), "hull")
    b.part("cabGlass", "box", (1.6, 0.4, 0.1), (-1.0, d + 0.8, -2.52), "glass")
    nano_arm(b, d, 0.9, 1.2, "order")
    out.append(b)

    b = B("ord_magistrate", ["Magistrate (Order combat engineer, T2): a heavier tracked hull with a dozer", "blade, a constructor arm (`nano`) and a light gun turret behind it. " + HEADER])
    d = tracked(b, 8.4, 5.6, 1.2, "order")
    b.part("blade", "box", (5.8, 1.2, 0.3), (0, 1.0, -4.9), "metal", rot=(-15, 0, 0))
    nano_arm(b, d, -1.2, -0.8, "order", 3.4)
    turret_gun(b, d, 2.0, 1.8, 0.7, 1.8, 0.24, 2.0, team=False)
    out.append(b)

    b = B("ord_whisper", ["Whisper (Order cloaked tank, T2): low and faceted, a flat wedge turret with", "no hard edges and a shrouded gun; the hull sides are angled plates. " + HEADER])
    d = tracked(b, 8.0, 5.2, 0.9, "order")
    b.part("facetL", "wedge", (1.4, 0.8, 7.0), (-2.0, d - 0.1, 0), "dark", rot=(0, 0, 90))
    b.part("facetR", "wedge", (1.4, 0.8, 7.0), (2.0, d - 0.1, 0), "dark", rot=(0, 0, -90))
    ty = d + 0.35
    b.part("turret", "wedge", (3.2, 0.7, 3.8), (0, ty, 0.2), "team")
    b.part("turretBack", "box", (3.2, 0.7, 1.0), (0, ty, 2.5), "team", parent="turret")
    b.part("barrel", "box", (0.6, 0.45, 4.0), (0, ty, -3.3), "dark", parent="turret", pivot=(0, ty, -1.6))
    b.attach("muzzle", "barrel", (0, ty, -5.3))
    out.append(b)

    b = B("ord_fulgur", ["Fulgur (Order lightning tank with an anti-air missile, T2): a turret with a", "lightning coil on top and a small missile box at its side. " + HEADER])
    d = tracked(b, 8.2, 5.4, 1.1, "order")
    b.part("turret", "box", (3.2, 0.9, 3.4), (0, d + 0.45, 0.3), "team")
    # the coil stands on the pitching `barrel` mount, so it tilts to aim
    b.part("barrel", "box", (1.2, 0.3, 1.2), (0, d + 1.05, -0.2), "dark", parent="turret", pivot=(0, d + 1.05, -0.2))
    coil(b, 0, d + 1.2, -0.2, 2.0, 0.5, "barrel", 1)
    b.attach("muzzle", "barrel", (0, d + 3.7, -0.2))
    b.part("missile", "box", (0.8, 0.8, 1.8), (1.9, d + 1.0, 0.4), "hull", parent="turret")  # the AA weapon's muzzle piece
    out.append(b)

    b = B("ord_mandate", ["Mandate (Order mobile artillery, T2): a long hull with the turret set back and", "a long howitzer with a recoil sleeve; spades at the rear. " + HEADER])
    d = tracked(b, 9.0, 5.4, 1.1, "order")
    ty = turret_gun(b, d, 1.8, 3.2, 1.3, 3.6, 0.5, 7.0)
    b.part("sleeve", "cylinder", (0.8, 0.8, 1.6), (0, ty, -0.8), "hull", parent="barrel", axis="z")
    b.part("spades", "box", (4.6, 0.8, 0.3), (0, 0.6, 4.9), "metal", rot=(30, 0, 0))
    out.append(b)

    b = B("ord_luminary", ["Luminary (Order mobile tachyon-beam tank, heavy T2): a broad heavy hull and a", "tall turret carrying a long beam emitter ringed with lenses. " + HEADER])
    d = tracked(b, 9.6, 6.4, 1.3, "order")
    ty = turret_gun(b, d, 0.8, 3.8, 1.4, 4.0, 0.7, 6.0)
    for i in range(3):
        b.part(f"lens{i + 1}", "cylinder", (1.1, 1.1, 0.25), (0, ty, -2.6 - i * 1.6), "glass", parent="barrel", axis="z")
    b.part("capacitor", "box", (3.0, 0.9, 1.6), (0, ty + 0.2, 3.4), "hull", parent="turret")
    out.append(b)

    b = B("ord_thunderer", ["Thunderer (Order huge lightning and EMP tank, T3): a wide double-tracked hull,", "a big turret with two lightning coils and an EMP dish between them. " + HEADER])
    d = tracked(b, 14.0, 10.0, 1.8, "order", tw=2.0)
    b.part("turret", "box", (6.4, 1.8, 6.2), (0, d + 0.9, 0.8), "team")
    b.part("turretFront", "wedge", (6.4, 1.8, 1.6), (0, d + 0.9, -3.1), "team", parent="turret")
    # both coils stand on one pitching `barrel` cross-mount
    b.part("barrel", "box", (5.6, 0.5, 1.8), (0, d + 2.05, 0.2), "dark", parent="turret", pivot=(0, d + 2.05, 0.2))
    coil(b, -2.0, d + 2.3, 0.2, 3.0, 0.8, "barrel", 1)
    coil(b, 2.0, d + 2.3, 0.2, 3.0, 0.8, "barrel", 2)
    b.part("emp", "cylinder", (2.4, 0.3, 2.4), (0, d + 2.6, 2.2), "glass", parent="turret", axis="y", rot=(-25, 0, 0))
    b.attach("muzzle", "barrel", (-2.0, d + 5.8, 0.2))
    b.attach("muzzle2", "barrel", (2.0, d + 5.8, 0.2))
    b.attach("emp", "turret", (0, d + 2.8, 2.2))
    out.append(b)

    b = B("ord_skimwright", ["Skimwright (Order hover constructor): a broad skirted hull with a cab", "and a constructor arm (`nano`). " + HEADER])
    d = hover(b, 7.0, 5.0, 0.9, "order")
    b.part("cab", "box", (2.0, 1.1, 1.8), (-1.1, d + 0.55, -1.5), "hull")
    b.part("cabGlass", "box", (1.6, 0.4, 0.1), (-1.1, d + 0.75, -2.42), "glass")
    nano_arm(b, d, 1.0, 0.2, "order")
    out.append(b)

    b = B("ord_skimmer", ["Skimmer (Order hover tank): a skirted hull with a compact gun turret. " + HEADER])
    d = hover(b, 7.0, 4.8, 0.9, "order")
    turret_gun(b, d, -0.2, 2.6, 0.8, 2.6, 0.32, 3.2)
    out.append(b)

    b = B("ord_volley", ["Volley (Order hover rocket artillery): a skirted hull with a tall rocket box", "that pitches up to fire. " + HEADER])
    d = hover(b, 7.6, 5.0, 0.9, "order")
    rocket_rack(b, d, 0.0, 3.0, 1.6, 2.8, 4, "order")
    out.append(b)

    b = B("ord_dart", ["Dart (Order fast light hover raider): small and narrow, one fan, a light gun. " + HEADER])
    d = hover(b, 5.4, 3.6, 0.7, "order", fans=1)
    turret_gun(b, d, -0.6, 1.6, 0.6, 1.6, 0.22, 2.2)
    out.append(b)

    b = B("ord_halcyon", ["Halcyon (Order hover anti-air): a skirted hull with a turret of two", "missile pods that pitch up, and a radar dish. " + HEADER])
    d = hover(b, 7.0, 4.8, 0.9, "order")
    b.part("turret", "cylinder", (2.4, 0.6, 2.4), (0, d + 0.3, -0.2), "team", axis="y")
    y = d + 1.2
    b.part("launcher", "box", (0.5, 0.5, 0.5), (0, y, -0.2), "dark", parent="turret", pivot=(0, y, -0.2))
    for s in (-1, 1):
        n = "L" if s < 0 else "R"
        b.part("pod" + n, "box", (0.9, 0.9, 2.0), (s * 1.0, y, -0.4), "hull", parent="launcher")
    b.part("radar", "cylinder", (1.2, 0.12, 1.2), (0, d + 1.9, 0.9), "metal", parent="turret", axis="z")
    b.attach("muzzle", "launcher", (-1.0, y, -1.45))
    b.attach("muzzle2", "launcher", (1.0, y, -1.45))
    out.append(b)

    b = B("ord_tempest", ["Tempest (Order heavy hovertank, T3): a large skirted hull, four fans and a", "heavy turret with twin long guns. " + HEADER])
    d = hover(b, 12.0, 8.4, 1.5, "order", fans=4)
    ty = turret_gun(b, d, -0.6, 4.8, 1.4, 4.6, 0.5, 6.0)
    b.part("barrel2", "cylinder", (0.5, 0.5, 6.0), (1.1, ty, -5.9), "metal", parent="barrel", axis="z")
    b.part("barrel1", "cylinder", (0.5, 0.5, 6.0), (-1.1, ty, -5.9), "metal", parent="barrel", axis="z")
    b.attach("muzzle2", "barrel", (1.1, ty, -8.9))
    out.append(b)

    b = B("ord_hoverdock", ["Hover Dock (Order hovercraft factory; stands on land or water): a deck on two", "pontoons, a covered bay at the back, three cranes and a slipway ramp. " + HEADER])
    factory(b, "order", 22)
    out.append(b)

    # --- Chaos ---
    b = B("chs_cleaver", ["Cleaver (Chaos riot tank, T1): a short angular hull and a squat turret with a", "wide, stubby scatter gun. " + HEADER])
    d = tracked(b, 6.4, 4.6, 1.0, "chaos")
    ty = turret_gun(b, d, 0.5, 2.6, 0.9, 2.4, 0.7, 1.8, team=False, faction="chaos")
    b.part("flare", "cylinder", (1.0, 1.0, 0.4), (0, ty, -3.2), "dark", parent="barrel", axis="z")
    out.append(b)

    b = B("chs_mudskipper", ["Mudskipper (Chaos light amphibious tank, T1): a low boat-bowed hull with open", "side floats, a small turret and gun. " + HEADER])
    d = amphib(b, 6.6, 4.4, 1.0, "chaos")
    turret_gun(b, d, 0.6, 2.2, 0.8, 2.2, 0.3, 2.8, team=False, faction="chaos")
    out.append(b)

    b = B("chs_dredger", ["Dredger (Chaos amphibious constructor, T1): the amphibious hull with an open", "cab and a constructor arm (`nano`) ending in a claw. " + HEADER])
    d = amphib(b, 7.0, 4.8, 1.1, "chaos")
    b.part("cab", "box", (1.8, 1.0, 1.6), (-1.1, d + 0.5, -1.7), "hull")
    nano_arm(b, d, 0.9, 1.0, "chaos", 3.4)
    b.part("claw", "wedge", (0.9, 0.9, 0.6), (0.9, d + 1.1, -2.7), "metal", parent="nano")
    out.append(b)

    b = B("chs_hellfire", ["Hellfire (Chaos heavy missile tank, T2): a heavy angular hull with a big", "armoured missile box (`launcher`) on a low turret. " + HEADER])
    d = tracked(b, 8.6, 5.8, 1.2, "chaos")
    rocket_rack(b, d, 0.6, 4.0, 1.8, 3.4, 6, "chaos")
    out.append(b)

    b = B("chs_grendel", ["Grendel (Chaos very heavy amphibious tank, T2): a broad boat-bowed hull with", "heavy floats, a massive turret and a short heavy gun. " + HEADER])
    d = amphib(b, 10.0, 7.0, 1.6, "chaos")
    turret_gun(b, d, 0.8, 4.4, 1.5, 4.0, 0.8, 4.4, team=False, faction="chaos")
    out.append(b)

    b = B("chs_hurler", ["Hurler (Chaos mobile artillery, T2): an open-frame hull with the gun set far", "back on a short turret, a long howitzer and rear spades. " + HEADER])
    d = tracked(b, 9.0, 5.4, 1.0, "chaos")
    turret_gun(b, d, 2.2, 2.8, 1.1, 3.0, 0.55, 7.2, team=False, faction="chaos")
    b.part("spades", "box", (4.6, 0.8, 0.3), (0, 0.6, 4.9), "metal", rot=(30, 0, 0))
    out.append(b)

    b = B("chs_drifter", ["Drifter (Chaos hover constructor): a skirted open-frame hull with a", "constructor arm (`nano`). " + HEADER])
    d = hover(b, 7.0, 5.0, 0.8, "chaos")
    nano_arm(b, d, 0.6, 0.0, "chaos", 3.4)
    out.append(b)

    b = B("chs_snapjaw", ["Snapjaw (Chaos hover tank): a skirted hull with a jaw-like split prow and", "a compact gun turret. " + HEADER])
    d = hover(b, 7.0, 4.8, 0.9, "chaos")
    for s in (-1, 1):
        b.part("jaw" + ("L" if s < 0 else "R"), "wedge", (0.6, 0.7, 1.6), (s * 1.6, 1.1, -4.0), "metal")
    turret_gun(b, d, 0.0, 2.4, 0.8, 2.4, 0.32, 3.0, team=False, faction="chaos")
    out.append(b)

    b = B("chs_sling", ["Sling (Chaos hover rocket artillery): a skirted hull with an open rocket", "rail rack that pitches up to fire. " + HEADER])
    d = hover(b, 7.6, 5.0, 0.8, "chaos")
    rocket_rack(b, d, 0.2, 3.0, 1.4, 3.2, 3, "chaos")
    out.append(b)

    b = B("chs_gnat", ["Gnat (Chaos fast light hover raider): a tiny dart of a hull, one fan, a", "light gun. " + HEADER])
    d = hover(b, 5.0, 3.4, 0.6, "chaos", fans=1)
    turret_gun(b, d, -0.5, 1.4, 0.6, 1.6, 0.2, 2.2, team=False, faction="chaos")
    out.append(b)

    b = B("chs_skua", ["Skua (Chaos hover anti-air): a skirted hull with a turret of open missile", "rails that pitch up. " + HEADER])
    d = hover(b, 7.0, 4.8, 0.8, "chaos")
    rocket_rack(b, d, 0.0, 2.4, 1.0, 2.6, 4, "chaos")
    out.append(b)

    b = B("chs_glaive", ["Glaive (Chaos assault hovertank with a heavy laser): a long skirted hull and", "a turret with a long laser lance. " + HEADER])
    d = hover(b, 9.0, 6.0, 1.1, "chaos", fans=2)
    ty = turret_gun(b, d, 0.2, 3.0, 1.0, 3.2, 0.45, 5.0, team=False, faction="chaos")
    b.part("lens", "cylinder", (0.8, 0.8, 0.3), (0, ty, -6.0), "glass", parent="barrel", axis="z")
    out.append(b)

    b = B("chs_typhon", ["Typhon (Chaos heavy laser hovertank, T3): a big skirted hull, four fans, a", "massive turret with a heavy laser and exposed capacitor coils. " + HEADER])
    d = hover(b, 12.0, 8.4, 1.4, "chaos", fans=4)
    ty = turret_gun(b, d, -0.4, 4.6, 1.6, 4.6, 0.9, 6.4, team=False, faction="chaos")
    b.part("lens", "cylinder", (1.4, 1.4, 0.4), (0, ty, -8.8), "glass", parent="barrel", axis="z")
    for s in (-1, 1):
        b.part("cap" + ("L" if s < 0 else "R"), "cylinder", (0.8, 2.4, 0.8), (s * 1.8, ty + 1.6, 1.0), "glass",
               parent="turret", axis="y")
    out.append(b)

    b = B("chs_skimyard", ["Skim Yard (Chaos hovercraft factory; stands on land or water): a deck on", "pontoons, an open bay at the back, three cranes and a ramp, spiked corners. " + HEADER])
    factory(b, "chaos", 22)
    out.append(b)
    return out


if __name__ == "__main__":
    # optional: each def's pieces as JSON ({id: [piece, ...]}, from the defs), to fit the rigs to them
    PIECES = json.load(open(sys.argv[2], encoding="utf-8")) if len(sys.argv) > 2 else {}
    units = make_all()
    for b in units:
        b.fit(PIECES.get(b.uid))
        b.write()
    print(f"{len(units)} blockouts -> {OUT}")
