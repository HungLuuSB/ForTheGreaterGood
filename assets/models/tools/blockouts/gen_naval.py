"""Writes hand-made naval blockouts and the last generic structures (models
stream, queue item 9): python gen_naval.py <src/shared/Defs/Blockouts>.
Each file is plain Luau data, like the hand-written ones. Waterline at y = 0
(floating units sit on the drawn water surface, rig.md 2)."""
import os, sys

OUT = sys.argv[1]


def f(v):
    return f"{round(v, 3):g}"


def part(name, shape, size, at, color, parent="base", rot=None, axis=None, pivot=None):
    s = f'{{ name = "{name}"'
    if name != "base":
        s += f', parent = "{parent}"'
    s += f', shape = "{shape}"'
    if axis:
        s += f', axis = "{axis}"'
    s += f", size = {{ {', '.join(f(x) for x in size)} }}, at = {{ {', '.join(f(x) for x in at)} }}"
    if rot:
        s += f", rot = {{ {', '.join(f(x) for x in rot)} }}"
    if pivot:
        s += f", pivot = {{ {', '.join(f(x) for x in pivot)} }}"
    s += f', color = "{color}" }}'
    return s


def write(uid, comment, parts, attachments=None, visual=None):
    lines = ["--!strict"] + [f"-- {c}" for c in comment] + ["", "return {", f'\tid = "{uid}",']
    if visual:
        lines.append("\tvisualPieces = { " + ", ".join(f'"{v}"' for v in visual) + " },")
    lines.append("\tparts = {")
    lines += [f"\t\t{p}," for p in parts]
    lines.append("\t},")
    if attachments:
        lines.append("\tattachments = {")
        for name, parent, at in attachments:
            lines.append(f'\t\t{{ name = "{name}", parent = "{parent}", at = {{ {", ".join(f(x) for x in at)} }} }},')
        lines.append("\t},")
    lines.append("}")
    with open(os.path.join(OUT, f"{uid}.luau"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


# --- hulls --------------------------------------------------------------------

def hull(order, w, l, h=1.8):
    """Hull from y -0.5 (just below the waterline) to h - 0.5, a pointed bow
    wedge at the front, a deck team stripe."""
    y = h / 2 - 0.5
    p = [
        part("base", "box", (w, h, l), (0, y, 0), "hull"),
        part("bow", "wedge", (w, h, l * 0.22), (0, y, -l / 2 - l * 0.11), "hull"),
        part("waterline", "box", (w + 0.1, 0.3, l), (0, -0.2, 0), "dark"),
    ]
    if order:
        p.append(part("deckTeam", "box", (w * 0.5, 0.08, l * 0.12), (0, h - 0.46, -l * 0.3), "team"))
    else:
        p.append(part("deckTeam", "box", (w * 0.7, 0.08, l * 0.08), (0, h - 0.46, l * 0.36), "team"))
    return p, h - 0.5


def gun(name, at, size, order, parent="base", barrels=1, length=None):
    """A turret piece: an armored house (Order) or open round mount (Chaos)
    with barrels toward -Z. Returns parts and the muzzle position."""
    x, y, z = at
    w, hgt, d = size
    length = length or d * 1.2
    p = []
    if order:
        p.append(part(name, "box", (w, hgt, d), (x, y + hgt / 2, z), "hull", parent=parent, pivot=(x, y, z)))
        p.append(part(f"{name}Front", "wedge", (w, hgt, d * 0.4), (x, y + hgt / 2, z - d * 0.7), "hull", parent=name))
    else:
        p.append(part(name, "cylinder", (w, hgt, w), (x, y + hgt / 2, z), "hull", parent=parent, axis="y", pivot=(x, y, z)))
    bz = z - d / 2 - length / 2 - (d * 0.4 if order else 0)
    for i in range(barrels):
        bx = x + (i - (barrels - 1) / 2) * 0.45
        p.append(part(f"{name}Barrel{i}", "cylinder", (0.3, 0.3, length), (bx, y + hgt / 2, bz), "metal", parent=name, axis="z"))
    return p, (x, y + hgt / 2, bz - length / 2 - 0.1)


def mast(order, x, z, y0, height, name="mast"):
    if order:
        return [
            part(name, "box", (1.2, height, 1.2), (x, y0 + height / 2, z), "hull"),
            part(f"{name}Array", "box", (1.5, 1.0, 1.5), (x, y0 + height - 0.8, z), "dark"),
            part(f"{name}Glass", "box", (1.55, 0.25, 1.55), (x, y0 + height - 0.8, z), "glass"),
        ]
    return [
        part(name, "box", (0.25, height, 0.25), (x, y0 + height / 2, z), "dark"),
        part(f"{name}Brace", "box", (0.15, height * 0.8, 0.15), (x + 0.5, y0 + height * 0.4, z), "dark", rot=(0, 0, 8)),
        part(f"{name}Panel", "box", (1.4, 0.8, 0.15), (x, y0 + height - 0.3, z), "dark"),
        part(f"{name}Light", "box", (0.3, 0.3, 0.3), (x, y0 + height + 0.3, z), "glass"),
    ]


def superstructure(order, w, l, y0, z, height):
    if order:
        return [
            part("bridge", "box", (w, height, l), (0, y0 + height / 2, z), "hull"),
            part("bridgeGlass", "box", (w * 0.8, 0.3, 0.08), (0, y0 + height - 0.4, z - l / 2 - 0.04), "glass"),
            part("bridgeTeam", "box", (w * 0.7, 0.08, l * 0.6), (0, y0 + height + 0.04, z), "team"),
        ]
    return [
        part("bridge", "box", (w * 0.8, height * 0.8, l * 0.8), (0, y0 + height * 0.4, z), "hull"),
        part("bridgeSlit", "box", (w * 0.6, 0.2, 0.08), (0, y0 + height * 0.65, z - l * 0.4 - 0.04), "glass"),
        part("funnel", "cylinder", (0.9, 1.6, 0.9), (w * 0.2, y0 + height * 0.8 + 0.6, z + l * 0.5), "metal", axis="y"),
    ]


def small_ship(uid, order, comment, kind):
    w, l = (3.6, 9.0) if order else (3.2, 9.2)
    p, deck = hull(order, w, l)
    p += superstructure(order, w * 0.75, 2.2, deck, 0.6, 1.6 if order else 1.3)
    att = []
    if kind == "corvette":
        g, m1 = gun("turret1", (0, deck, -2.6), (1.4, 0.8, 1.6), order)
        p += g
        g2, m2 = gun("turret2", (0, deck, 3.3), (0.9, 0.6, 0.9), order, length=0.8)
        p += g2
        p += mast(order, 0, 1.2, deck + (1.6 if order else 1.0), 1.8)
        att = [("muzzle1", "turret1", m1), ("muzzle2", "turret2", m2)]
    elif kind in ("worker", "worker2"):
        p += [
            part("nano", "cylinder", (1.6, 0.4, 1.6), (0, deck + 0.2, 2.8), "team", axis="y"),
            part("crane", "box", (0.4, 0.4, 3.4), (0, deck + 1.3, 1.6), "dark", parent="nano", rot=(30, 0, 0)),
            part("emitter", "ball", (0.8, 0.8, 0.8), (0, deck + 2.2, 0.1), "glass", parent="nano"),
            part("cargo", "box", (w * 0.6, 0.6, 1.6), (0, deck + 0.3, -2.6), "dark"),
        ]
        if kind == "worker2":
            # T2: a second crane arm and emitter, a deck crane forward
            p += [
                part("crane2", "box", (0.4, 0.4, 2.4), (0, deck + 1.0, 3.8), "dark", parent="nano", rot=(-30, 0, 0)),
                part("emitter2", "ball", (0.6, 0.6, 0.6), (0, deck + 1.7, 4.8), "glass", parent="nano"),
                part("deckCrane", "box", (0.3, 2.4, 0.3), (w * 0.3, deck + 1.2, -1.4), "dark"),
                part("deckJib", "box", (0.3, 0.3, 2.4), (w * 0.3, deck + 2.3, -2.4), "dark"),
            ]
    elif kind == "jammer":
        # turret1 / turret2: two turning emitter masts (no weapon)
        for i, z in ((1, -2.4), (2, 3.0)):
            p.append(part(f"turret{i}", "cylinder", (0.9, 0.5, 0.9), (0, deck + 0.25, z), "dark", axis="y"))
            p.append(part(f"emitterMast{i}", "box", (0.2, 2.4, 0.2), (0, deck + 1.7, z), "dark", parent=f"turret{i}"))
            for k in range(4):
                p.append(part(f"rod{i}{k}", "box", (0.12, 0.12, 1.2), (0, deck + 2.2 + k * 0.35, z), "glass", parent=f"turret{i}", rot=(0, 45 * k, 0)))
            att.append((f"muzzle{i}", f"turret{i}", (0, deck + 3.2, z)))
    write(uid, comment, p, att or None)


def submarine(uid, order, comment):
    l = 9.4
    p = [
        part("base", "cylinder", (2.2, 2.2, l), (0, -0.6, 0), "hull", axis="z"),
        part("nose", "ball", (2.2, 2.2, 2.6), (0, -0.6, -l / 2), "hull"),
        part("tailCone", "cylinder", (1.2, 1.2, 1.6), (0, -0.6, l / 2 + 0.6), "dark", axis="z"),
        part("rudder", "box", (0.15, 1.8, 1.0), (0, -0.4, l / 2 + 0.9), "team"),
        part("planes", "box", (3.2, 0.12, 0.8), (0, -0.6, l / 2 + 0.6), "dark"),
    ]
    if order:
        p += [part("sail", "box", (0.9, 1.6, 2.4), (0, 1.1, -1.4), "hull"),
              part("sailTeam", "box", (0.94, 0.4, 1.6), (0, 1.5, -1.4), "team"),
              part("periscope", "box", (0.15, 0.8, 0.15), (0, 2.3, -1.0), "dark")]
    else:
        p += [part("sail", "box", (1.0, 1.3, 3.0), (0, 0.95, -0.8), "hull"),
              part("sailTeam", "box", (1.04, 0.4, 1.8), (0, 1.3, -0.8), "team"),
              part("snorkel", "box", (0.2, 1.0, 0.2), (0, 2.1, -0.2), "dark"),
              part("sensorGlow", "box", (0.6, 0.15, 0.06), (0, 1.2, -2.34), "glass")]
    # torpedo doors: turret1 bow, turret2 stern (turn with the weapon's aim)
    p += [part("turret1", "box", (1.0, 0.4, 0.8), (0, 0.4, -3.4), "dark", pivot=(0, 0.2, -3.4)),
          part("turret2", "box", (0.8, 0.3, 0.6), (0, 0.4, 3.0), "dark", pivot=(0, 0.2, 3.0))]
    write(uid, comment, p, [("muzzle1", "turret1", (0, 0.4, -3.9)), ("muzzle2", "turret2", (0, 0.4, 2.6))])


def big_ship(uid, order, comment, kind):
    w, l = (8.6, 24.0) if order else (7.6, 24.5)
    p, deck = hull(order, w, l, h=2.6)
    att = []
    if kind == "carrier":
        p += [
            part("flightDeck", "box", (w + 2.4, 0.4, l + 1.0), (0 if order else 0.6, deck + 0.4, -0.4), "dark"),
            part("deckLine", "box", (0.3, 0.06, l), (0 if order else 0.6, deck + 0.63, -0.4), "hull"),
            part("padTeamA", "box", (2.4, 0.06, 2.4), (-1.6, deck + 0.63, -6.0), "team"),
            part("padTeamB", "box", (2.4, 0.06, 2.4), (-1.6, deck + 0.63, 4.0), "team"),
        ]
        isl = (w / 2 - 0.2, deck + 0.6)
        if order:
            p += [part("island", "box", (2.0, 4.4, 5.0), (isl[0], isl[1] + 2.2, 2.0), "hull"),
                  part("islandGlass", "box", (2.05, 0.4, 5.05), (isl[0], isl[1] + 3.6, 2.0), "glass")]
            p += mast(True, isl[0], 2.6, isl[1] + 4.4, 2.0)
        else:
            p += [part("island", "box", (1.8, 3.4, 4.2), (-w / 2 + 0.4, isl[1] + 1.7, 3.0), "hull"),
                  part("islandSlit", "box", (1.84, 0.3, 4.24), (-w / 2 + 0.4, isl[1] + 2.6, 3.0), "glass")]
            p += mast(False, -w / 2 + 0.4, 3.0, isl[1] + 3.4, 3.4)
        g, m1 = gun("turret1", (-(w / 2) + 1.0 if order else w / 2 - 0.4, deck + 0.6, -9.5), (1.2, 0.7, 1.2), order, barrels=2, length=1.2)
        g2, m2 = gun("turret2", (-(w / 2) + 1.0 if order else w / 2 - 0.4, deck + 0.6, 9.0), (1.2, 0.7, 1.2), order, barrels=2, length=1.2)
        p += g + g2
        att = [("muzzle1", "turret1", m1), ("muzzle2", "turret2", m2)]
    else:
        p += superstructure(order, w * 0.6, 6.0, deck, 1.2, 3.2 if order else 2.6)
        p += mast(order, 0, 2.4, deck + (3.2 if order else 2.0), 4.0)
        big = kind == "cruiser"
        g, m1 = gun("turret1", (0, deck, -7.0), (3.0 if big else 2.2, 1.4 if big else 1.0, 3.0 if big else 2.2), order, barrels=3 if big else 1, length=4.4 if big else 3.0)
        p += g
        att.append(("muzzle1", "turret1", m1))
        if big:
            g2, m2 = gun("turret2", (0, deck, 7.6), (1.6, 0.8, 1.6), order, barrels=2, length=1.6)
            # a second heavy mount aft (decoration: the def has one heavy-gun piece)
            p += g2
            p += [part("aftMount", "box", (2.4, 1.2, 2.6), (0, deck + 0.6, 4.6), "hull"),
                  part("aftBarrels", "box", (1.0, 0.4, 3.0), (0, deck + 0.8, 2.4), "metal")]
            att.append(("muzzle2", "turret2", m2))
        else:
            g2, m2 = gun("turret2", (w / 2 - 1.0, deck, 4.4), (1.2, 0.6, 1.2), order, barrels=2, length=1.0)
            p += g2
            att.append(("muzzle2", "turret2", m2))
            # launcher: VLS block (Order) or a rail box (Chaos), turning
            if order:
                p += [part("launcher", "box", (2.6, 0.6, 2.4), (0, deck + 0.3, -3.6), "dark", pivot=(0, deck, -3.6))]
                for i in range(3):
                    for k in range(2):
                        p.append(part(f"cell{i}{k}", "box", (0.6, 0.06, 0.6), (-0.8 + i * 0.8, deck + 0.63, -4.0 + k * 0.8), "team" if (i + k) % 2 == 0 else "metal", parent="launcher"))
            else:
                p += [part("launcher", "box", (1.6, 0.8, 2.2), (-w / 2 + 1.4, deck + 0.4, 5.4), "dark", pivot=(-w / 2 + 1.4, deck, 5.4)),
                      part("rails", "box", (1.2, 0.4, 2.8), (-w / 2 + 1.4, deck + 1.1, 5.2), "metal", parent="launcher", rot=(25, 0, 0))]
            att.append(("muzzle3", "launcher", (0 if order else -w / 2 + 1.4, deck + 1.4, -3.6 if order else 4.0)))
    write(uid, comment, p, att)


O = True
C = False
small_ship("ord_sentry", O, ["Sentry (Order corvette, T1, footprint 1): a faceted hull, a tall boxy",
                             "bridge with a glass band and team roof, a gun house forward (`turret1`)",
                             "and a small aft mount (`turret2`), a solid mast.",
                             "Model space, forward = -Z."], "corvette")
small_ship("chs_barracuda", C, ["Barracuda (Chaos corvette, T1, footprint 1): a low hull, a squat",
                                "bridge with a slit and a funnel, an open gun mount forward",
                                "(`turret1`), a small aft mount (`turret2`), a lattice mast.",
                                "Model space, forward = -Z."], "corvette")
small_ship("ord_tidewright", O, ["Tidewright (Order naval builder, T1, footprint 1): a faceted hull with",
                                 "a cargo hatch forward and a `nano` crane with a glowing emitter aft.",
                                 "Model space, forward = -Z."], "worker")
small_ship("chs_wrecker", C, ["Wrecker (Chaos naval builder, T1, footprint 1): a low hull with a cargo",
                              "hatch and a `nano` crane with a glowing emitter aft.",
                              "Model space, forward = -Z."], "worker")
small_ship("ord_harbormaster", O, ["Harbormaster (Order advanced naval builder, T2, footprint 1): the",
                                   "Tidewright hull with a second `nano` arm and emitter and a deck crane.",
                                   "Model space, forward = -Z."], "worker2")
small_ship("chs_reaver", C, ["Reaver (Chaos advanced naval builder, T2, footprint 1): the Wrecker",
                             "hull with a second `nano` arm and emitter and a deck crane.",
                             "Model space, forward = -Z."], "worker2")
small_ship("chs_siren", C, ["Siren (Chaos naval jammer, T2, footprint 1): a low hull with two turning",
                            "emitter masts (`turret1`, `turret2`) ringed with glowing rods.",
                            "Model space, forward = -Z."], "jammer")
submarine("ord_silence", O, ["Silence (Order submarine, T1, footprint 1): a long smooth hull mostly under",
                             "the waterline, a tall faceted sail with a team band, cruciform stern",
                             "planes; torpedo doors at the bow (`turret1`) and stern (`turret2`).",
                             "Model space, forward = -Z."])
submarine("chs_lamprey", C, ["Lamprey (Chaos submarine, T1, footprint 1): a hull mostly under the",
                             "waterline, a long low sail with a snorkel and an orange sensor strip;",
                             "torpedo doors at the bow (`turret1`) and stern (`turret2`).",
                             "Model space, forward = -Z."])
big_ship("ord_crusader", O, ["Crusader (Order destroyer, T2, footprint 3): a faceted hull, a tall",
                             "block superstructure with a glass band and solid mast, a gun house",
                             "forward (`turret1`), an ASW torpedo mount (`turret2`), a VLS block",
                             "(`launcher`) with team cells. Model space, forward = -Z."], "destroyer")
big_ship("chs_corsair", C, ["Corsair (Chaos destroyer, T2, footprint 3): a low hull, a squat bridge",
                            "with a funnel and a lattice mast, an open gun mount forward (`turret1`),",
                            "an ASW torpedo mount (`turret2`), a SAM rail box (`launcher`).",
                            "Model space, forward = -Z."], "destroyer")
big_ship("ord_dominion", O, ["Dominion (Order cruiser, T2, footprint 3): a big faceted hull, a triple",
                             "gun house forward (`turret1`), a flak mount aft (`turret2`), a second",
                             "triple mount aft (decoration), a tall block superstructure.",
                             "Model space, forward = -Z."], "cruiser")
big_ship("chs_kraken", C, ["Kraken (Chaos cruiser, T2, footprint 3): a low long hull, a triple open",
                           "gun mount forward (`turret1`), flak aft (`turret2`), a squat bridge with",
                           "funnel and lattice mast. Model space, forward = -Z."], "cruiser")
big_ship("ord_sanctuary", O, ["Sanctuary (Order carrier, T2, footprint 3): a full flight deck with",
                              "team pads, a tall island to starboard with a glass band and solid",
                              "radar mast, flak mounts fore and aft (`turret1`, `turret2`).",
                              "Model space, forward = -Z."], "carrier")
big_ship("chs_leviathan", C, ["Leviathan (Chaos carrier, T2, footprint 3): an offset flight deck with",
                              "team pads, a low island to port with a lattice radar mast, flak",
                              "mounts fore and aft (`turret1`, `turret2`). Model space, forward = -Z."], "carrier")

# --- structures -------------------------------------------------------------

def airpad(uid, order, comment):
    p = [part("base", "box", (22, 0.6, 22), (0, 0.3, 0), "dark" if not order else "hull"),
         part("pad", "cylinder", (14, 0.2, 14), (0, 0.7, 0), "dark", axis="y"),
         part("ring", "cylinder", (14.4, 0.15, 14.4), (0, 0.66, 0), "team", axis="y"),
         part("markA", "box", (0.6, 0.06, 6), (-1.6, 0.83, 0), "hull"),
         part("markB", "box", (0.6, 0.06, 6), (1.6, 0.83, 0), "hull"),
         part("markC", "box", (3.2, 0.06, 0.6), (0, 0.83, 0), "hull")]
    for i, (x, z) in enumerate(((-9, -9), (9, -9), (-9, 9), (9, 9))):
        p.append(part(f"light{i}", "box", (0.5, 0.5, 0.5), (x, 0.85, z), "glass"))
    if order:
        p += [part("armL", "box", (1.2, 2.4, 1.2), (-9.4, 1.8, 0), "hull"),
              part("armBoom", "box", (3.6, 0.6, 0.6), (-7.6, 3.0, 0), "hull"),
              part("fuel", "box", (3.0, 1.6, 2.0), (8.6, 1.4, -6.0), "hull"),
              part("fuelTeam", "box", (2.2, 0.08, 1.2), (8.6, 2.24, -6.0), "team")]
    else:
        p += [part("tankA", "cylinder", (2.4, 2.6, 2.4), (8.6, 1.9, -7.6), "metal", axis="y"),
              part("tankB", "cylinder", (2.4, 2.6, 2.4), (8.6, 1.9, -4.6), "metal", axis="y"),
              part("hose", "box", (0.25, 0.25, 6.0), (6.4, 0.9, -3.0), "dark"),
              part("mast", "box", (0.25, 5.0, 0.25), (-9.6, 3.1, 9.6), "dark"),
              part("mastLight", "box", (0.4, 0.4, 0.4), (-9.6, 5.8, 9.6), "glass")]
    write(uid, comment, p)


def converter(uid, order, comment):
    if order:
        p = [part("base", "box", (6, 1.2, 6), (0, 0.6, 0), "hull"),
             part("housing", "box", (4.4, 2.4, 4.4), (0, 2.4, 0), "hull"),
             part("coil", "cylinder", (2.4, 2.0, 2.4), (0, 4.6, 0), "glass", axis="y"),
             part("coilCap", "cylinder", (2.8, 0.4, 2.8), (0, 5.8, 0), "dark", axis="y"),
             part("team", "box", (3.4, 0.08, 1.0), (0, 3.64, -1.6), "team"),
             part("pipeL", "box", (0.5, 0.5, 5.6), (-2.6, 1.5, 0), "metal"),
             part("pipeR", "box", (0.5, 0.5, 5.6), (2.6, 1.5, 0), "metal")]
    else:
        p = [part("base", "box", (6, 0.5, 6), (0, 0.25, 0), "dark"),
             part("tank", "cylinder", (3.6, 3.0, 3.6), (0, 2.0, 0.6), "metal", axis="y"),
             part("glowBand", "cylinder", (3.7, 0.3, 3.7), (0, 2.6, 0.6), "glass", axis="y"),
             part("team", "box", (2.4, 0.08, 1.0), (0, 0.54, -2.2), "team"),
             part("pipeA", "box", (0.4, 2.6, 0.4), (-2.2, 1.8, -1.6), "dark"),
             part("pipeB", "box", (2.6, 0.4, 0.4), (-1.0, 3.1, -1.6), "dark"),
             part("stack", "cylinder", (0.5, 2.4, 0.5), (2.2, 2.2, -1.8), "dark", axis="y")]
    write(uid, comment, p)


def tidal(uid, order, comment):
    if order:
        p = [part("base", "box", (6, 1.0, 6), (0, 0.2, 0), "hull"),
             part("housing", "cylinder", (3.0, 1.6, 3.0), (0, 1.5, 0), "hull", axis="y"),
             part("team", "box", (2.0, 0.08, 1.0), (0, 0.74, -2.3), "team"),
             part("ring", "cylinder", (3.2, 0.25, 3.2), (0, 0.9, 0), "glass", axis="y"),
             part("turbine", "cylinder", (2.4, 0.6, 2.4), (0, -0.6, 0), "metal", axis="z")]
    else:
        p = [part("base", "box", (5.6, 0.4, 3.2), (0, 0.8, 0), "dark"),
             part("floatL", "cylinder", (1.4, 1.4, 5.4), (-2.0, 0.3, 0), "metal", axis="z"),
             part("floatR", "cylinder", (1.4, 1.4, 5.4), (2.0, 0.3, 0), "metal", axis="z"),
             part("rotor", "cylinder", (2.6, 0.3, 2.6), (0, -0.3, 0), "hull", axis="x"),
             part("team", "box", (1.6, 0.08, 1.0), (0, 1.04, 0), "team"),
             part("light", "box", (0.4, 0.4, 0.4), (2.0, 1.2, 2.4), "glass")]
    write(uid, comment, p)


def torpedo(uid, order, comment):
    if order:
        p = [part("base", "box", (6, 1.0, 6), (0, 0.2, 0), "hull"),
             part("team", "box", (3.0, 0.08, 1.0), (0, 0.74, 2.3), "team"),
             part("turret", "cylinder", (2.4, 0.8, 2.4), (0, 1.1, -0.6), "dark", axis="y"),
             part("sonar", "cylinder", (2.0, 0.6, 2.0), (0, -0.4, 0), "glass", axis="y"),
             part("launcher", "box", (2.6, 1.0, 3.0), (0, 1.9, -0.6), "hull", pivot=(0, 1.4, -0.6))]
        for i, x in enumerate((-0.7, 0.0, 0.7)):
            p.append(part(f"tube{i}", "cylinder", (0.5, 0.5, 3.4), (x, 1.9, -0.8), "metal", parent="launcher", axis="z"))
        att = [("muzzle", "launcher", (0, 1.9, -2.6))]
    else:
        p = [part("base", "box", (5.6, 0.4, 3.0), (0, 0.8, 0), "dark"),
             part("floatL", "cylinder", (1.3, 1.3, 5.6), (-2.1, 0.3, 0), "metal", axis="z"),
             part("floatR", "cylinder", (1.3, 1.3, 5.6), (2.1, 0.3, 0), "metal", axis="z"),
             part("team", "box", (1.6, 0.08, 0.8), (0, 1.04, 1.0), "team"),
             part("turret", "cylinder", (1.8, 0.5, 1.8), (0, 1.25, -0.3), "dark", axis="y"),
             part("sonar", "box", (0.6, 0.15, 0.06), (1.6, 1.1, -1.5), "glass"),
             part("launcher", "box", (1.6, 0.3, 2.6), (0, 1.65, -0.3), "dark", pivot=(0, 1.5, -0.3))]
        for i, x in enumerate((-0.45, 0.45)):
            p.append(part(f"tube{i}", "cylinder", (0.55, 0.55, 3.6), (x, 2.05, -0.6), "metal", parent="launcher", axis="z"))
        att = [("muzzle", "launcher", (0, 2.05, -2.5))]
    write(uid, comment, p, att)


def naval_turret(uid, order, comment):
    if order:
        p = [part("base", "box", (6.4, 1.6, 6.4), (0, 0.4, 0), "hull"),
             part("wallF", "wedge", (6.4, 1.6, 0.8), (0, 0.4, -3.6), "hull"),
             part("team", "box", (4.0, 0.08, 1.0), (0, 1.24, 2.4), "team"),
             part("light", "box", (0.5, 0.5, 0.5), (2.6, 1.45, 2.6), "glass")]
        g, m = gun("turret", (0, 1.2, 0), (3.2, 1.4, 3.2), True, barrels=2, length=3.6)
    else:
        p = [part("base", "cylinder", (6.4, 1.0, 6.4), (0, 0.2, 0), "dark", axis="y"),
             part("float", "cylinder", (6.8, 0.6, 6.8), (0, -0.2, 0), "metal", axis="y"),
             part("team", "box", (2.4, 0.08, 1.0), (0, 0.74, 2.2), "team"),
             part("light", "box", (0.4, 0.4, 0.4), (2.4, 0.9, 1.6), "glass")]
        g, m = gun("turret", (0, 0.7, 0), (3.0, 1.2, 3.0), False, barrels=1, length=3.4)
    write(uid, comment, p + g, [("muzzle", "turret", m)])


airpad("ord_airpad", O, ["Airpad (Order rearm pad, T1, footprint 3): an armored square apron with a",
                         "landing circle ringed in team color, edge lights, a rearm arm and a fuel",
                         "block. Model space, forward = -Z."])
airpad("chs_airpad", C, ["Airpad (Chaos rearm pad, T1, footprint 3): a grated apron with a landing",
                         "circle ringed in team color, fuel tanks with a hose, a lattice light",
                         "mast. Model space, forward = -Z."])
converter("ord_converter", O, ["Converter (Order supply converter, T1, footprint 1): an armored block",
                               "with a glowing coil and cap, side pipes, a team plate.",
                               "Model space, forward = -Z."])
converter("chs_converter", C, ["Converter (Chaos supply converter, T1, footprint 1): a tank with a",
                               "glowing band, exposed pipework and a stack on a skid.",
                               "Model space, forward = -Z."])
tidal("ord_tidal", O, ["Tidal (Order tidal generator, T1, footprint 1): a floating armored pad, a",
                       "round housing with a glowing ring, a turbine under the water.",
                       "Model space, forward = -Z."])
tidal("chs_tidal", C, ["Tidal (Chaos tidal generator, T1, footprint 1): two floats under a deck with",
                       "an exposed water rotor between them. Model space, forward = -Z."])
torpedo("ord_undertow", O, ["Undertow (Order torpedo launcher, T1, footprint 1): a floating armored",
                            "pad with a sonar dome below, a turntable (`turret`) and a three-tube",
                            "`launcher` house (the weapon turns it). Model space, forward = -Z."])
torpedo("chs_fang", C, ["Fang (Chaos torpedo launcher, T1, footprint 1): a pontoon raft, a turntable",
                        "(`turret`) and two bare tubes on the `launcher` (the weapon turns it).",
                        "Model space, forward = -Z."])
naval_turret("ord_moat", O, ["Moat (Order floating turret, T1, footprint 1): an armored floating",
                             "casemate with a twin gun house (`turret`). Model space, forward = -Z."])
naval_turret("chs_riptide", C, ["Riptide (Chaos floating turret, T1, footprint 1): a round float with an",
                                "open single-gun mount (`turret`). Model space, forward = -Z."])
print("ok")
