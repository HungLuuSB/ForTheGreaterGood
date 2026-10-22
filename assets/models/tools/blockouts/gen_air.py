"""Writes hand-made air blockouts (models stream, queue item 9).
Each file is plain Luau data, like the hand-written ones."""
import os, sys

OUT = sys.argv[1]


def f(v):
    return f"{v:g}"


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
    lines = ["--!strict"] + [f"-- {c}" if c else "--" for c in comment] + ["", "return {", f'\tid = "{uid}",']
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


# --- jets -------------------------------------------------------------------

def order_jet(uid, comment, length=7.4, span=6.4, extra=(), pieces=("pylon",), stealth=False):
    """Order jet: a flat angular fuselage, swept wings, canted twin tails
    (team), cockpit glass, twin engine glow; the weapon pylon under the
    wing roots."""
    l2 = length / 2
    p = [
        part("base", "box", (1.6, 0.9, length), (0, 0.6, 0), "hull"),
        part("nose", "wedge", (1.6, 0.9, 1.6), (0, 0.6, -l2 - 0.8), "hull"),
        part("canopy", "wedge", (0.8, 0.45, 1.6), (0, 1.25, -l2 + 1.4), "glass"),
        part("wingL", "wedge", (span / 2 - 0.8, 0.2, 3.2), (-(span / 4 + 0.4), 0.45, 0.6), "hull", rot=(0, -90, 0)),
        part("wingR", "wedge", (span / 2 - 0.8, 0.2, 3.2), ((span / 4 + 0.4), 0.45, 0.6), "hull", rot=(0, 90, 0)),
        part("wingTeamL", "box", (1.2, 0.06, 1.0), (-(span / 4 + 0.6), 0.6, 1.0), "team"),
        part("wingTeamR", "box", (1.2, 0.06, 1.0), ((span / 4 + 0.6), 0.6, 1.0), "team"),
        part("tailL", "box", (0.15, 1.3, 1.4), (-0.6, 1.55, l2 - 0.8), "team", rot=(0, 0, -15)),
        part("tailR", "box", (0.15, 1.3, 1.4), (0.6, 1.55, l2 - 0.8), "team", rot=(0, 0, 15)),
        part("engineL", "cylinder", (0.6, 0.6, 0.3), (-0.45, 0.6, l2 + 0.1), "glass", axis="z"),
        part("engineR", "cylinder", (0.6, 0.6, 0.3), (0.45, 0.6, l2 + 0.1), "glass", axis="z"),
    ]
    if stealth:
        p[3] = part("wingL", "wedge", (span / 2 - 0.8, 0.25, 4.6), (-(span / 4 + 0.4), 0.5, 0.4), "hull", rot=(0, -90, 0))
        p[4] = part("wingR", "wedge", (span / 2 - 0.8, 0.25, 4.6), ((span / 4 + 0.4), 0.5, 0.4), "hull", rot=(0, 90, 0))
    p += list(extra)
    att = []
    if "pylon" in pieces:
        p.append(part("pylon", "box", (2.4, 0.3, 1.6), (0, 0.05, 0.2), "dark"))
        p.append(part("missileL", "cylinder", (0.3, 0.3, 2.0), (-0.9, -0.15, -0.1), "metal", parent="pylon", axis="z"))
        p.append(part("missileR", "cylinder", (0.3, 0.3, 2.0), (0.9, -0.15, -0.1), "metal", parent="pylon", axis="z"))
        att.append(("muzzle", "pylon", (0, -0.15, -1.2)))
    if "turret" in pieces:
        p.append(part("turret", "cylinder", (0.8, 0.5, 0.8), (0, 0.0, -l2 + 0.9), "dark", axis="y"))
        p.append(part("sensor", "ball", (0.4, 0.4, 0.4), (0, -0.15, -l2 + 0.6), "glass", parent="turret"))
        att = [("muzzle", "turret", (0, -0.1, -l2 + 0.3))]
    return p, att


def chaos_jet(uid, length=7.0, span=6.8, extra=(), pieces=("pylon",)):
    """Chaos jet: a round fuselage, a big delta wing, canards, one tall tail
    (team), exposed engine pods with orange glow; pylon under the belly."""
    l2 = length / 2
    p = [
        part("base", "cylinder", (1.3, 1.3, length), (0, 0.7, 0), "hull", axis="z"),
        part("nose", "wedge", (1.2, 1.0, 1.8), (0, 0.65, -l2 - 0.9), "hull"),
        part("canopy", "ball", (0.8, 0.6, 1.4), (0, 1.35, -l2 + 1.3), "glass"),
        part("delta", "wedge", (span, 0.2, 4.4), (0, 0.5, 1.0), "hull"),
        part("deltaTeam", "box", (span * 0.5, 0.06, 1.0), (0, 0.62, 2.4), "team"),
        part("canardL", "box", (1.6, 0.12, 0.7), (-1.1, 0.9, -l2 + 1.6), "dark"),
        part("canardR", "box", (1.6, 0.12, 0.7), (1.1, 0.9, -l2 + 1.6), "dark"),
        part("tail", "box", (0.18, 1.9, 1.8), (0, 2.0, l2 - 0.9), "team"),
        part("podL", "cylinder", (0.7, 0.7, 2.4), (-1.0, 0.45, l2 - 1.0), "metal", axis="z"),
        part("podR", "cylinder", (0.7, 0.7, 2.4), (1.0, 0.45, l2 - 1.0), "metal", axis="z"),
        part("glowL", "cylinder", (0.55, 0.55, 0.2), (-1.0, 0.45, l2 + 0.25), "glass", axis="z"),
        part("glowR", "cylinder", (0.55, 0.55, 0.2), (1.0, 0.45, l2 + 0.25), "glass", axis="z"),
    ]
    p += list(extra)
    att = []
    if "pylon" in pieces:
        p.append(part("pylon", "box", (1.0, 0.35, 2.4), (0, -0.05, 0), "dark"))
        for i, x in enumerate((-0.6, 0.6, -1.4, 1.4)):
            p.append(part(f"missile{i}", "cylinder", (0.25, 0.25, 1.6), (x, -0.3, -0.2), "metal", parent="pylon", axis="z"))
        att.append(("muzzle", "pylon", (0, -0.3, -1.2)))
    if "turret" in pieces:
        p.append(part("turret", "cylinder", (0.8, 0.5, 0.8), (0, 0.0, -l2 + 1.0), "dark", axis="y"))
        p.append(part("sensor", "ball", (0.4, 0.4, 0.4), (0, -0.15, -l2 + 0.7), "glass", parent="turret"))
        att = [("muzzle", "turret", (0, -0.1, -l2 + 0.4))]
    return p, att


def bomber_parts(p, length, team_bay=False):
    l2 = length / 2
    p.append(part("bay", "box", (1.2, 0.2, 2.6), (0, 0.1, 0.2), "dark"))
    p.append(part("bayLip", "box", (1.4, 0.1, 0.2), (0, 0.05, -1.1), "metal", parent="bay"))
    return [("muzzle", "bay", (0, -0.1, 0.2))]


# Order
p, a = order_jet("ord_falcon", "")
write("ord_falcon", ["Falcon (Order fighter, T1, footprint 1): a flat angular fuselage, swept",
                     "wings, canted twin tails in team color, twin engine glow; two precise",
                     "missiles on the `pylon` under the wing roots (the weapon turns it).",
                     "Model space, forward = -Z."], p, a)
p, a = order_jet("ord_archon", "", length=8.2, span=6.8, pieces=("pylon", "turret"), stealth=True)
write("ord_archon", ["Archon (Order air superiority fighter, T2, footprint 1): longer than the",
                     "Falcon with broad stealth-shaped wings and canted tails, a chin sensor",
                     "`turret` (its radar missiles turn it), the missile `pylon` under the",
                     "wing roots. Model space, forward = -Z."], p, a)
p, a = order_jet("ord_absolution", "", length=8.0, span=7.4, pieces=())
p.append(part("pylon", "box", (5.2, 0.25, 0.8), (0, 0.2, 1.0), "dark"))
a = bomber_parts(p, 8.0)
write("ord_absolution", ["Absolution (Order bomber, T1, footprint 1): the Order jet stretched, with",
                         "a deep belly, a bomb `bay` with doors under it and a wing `pylon` rail",
                         "for heavy bombs. Model space, forward = -Z."], p, a)
# Phantom: flying wing
p = [
    part("base", "wedge", (2.4, 1.0, 5.6), (0, 0.6, 0.4), "hull"),
    part("wing", "wedge", (8.0, 0.3, 4.4), (0, 0.35, 1.4), "hull"),
    part("wingTeamL", "box", (1.6, 0.06, 1.0), (-2.4, 0.55, 2.4), "team"),
    part("wingTeamR", "box", (1.6, 0.06, 1.0), (2.4, 0.55, 2.4), "team"),
    part("canopy", "wedge", (0.9, 0.35, 1.2), (0, 1.2, -1.2), "glass"),
    part("exhaust", "box", (2.0, 0.2, 0.2), (0, 0.5, 3.4), "glass"),
    part("pylon", "box", (2.0, 0.2, 0.8), (0, 0.15, 1.6), "dark"),
]
a = bomber_parts(p, 5.6)
write("ord_phantom", ["Phantom (Order strategic bomber, T2, footprint 1): a stealth flying wing",
                      "(no tails), a raised spine with a slim canopy, a slit exhaust, a bomb",
                      "`bay` and a `pylon`; team panels on the wing tips.",
                      "Model space, forward = -Z."], p, a)
p, a = order_jet("ord_archangel", "", length=8.6, span=7.6, pieces=())
p += [
    part("strutF", "box", (0.25, 0.8, 0.25), (0, 1.4, -0.8), "dark"),
    part("strutB", "box", (0.25, 0.8, 0.25), (0, 1.4, 1.4), "dark"),
    part("dish", "box", (0.5, 0.5, 5.2), (0, 2.0, 0.3), "hull"),
    part("dishFaceL", "box", (0.06, 0.35, 4.8), (-0.27, 2.0, 0.3), "glass", parent="dish"),
    part("dishFaceR", "box", (0.06, 0.35, 4.8), (0.27, 2.0, 0.3), "glass", parent="dish"),
]
write("ord_archangel", ["Archangel (Order AWACS, T2, footprint 1): a long Order jet carrying the",
                        "`dish`: a flat plank radar (a panel, never a dish) on two struts along",
                        "the spine, glowing on both faces. Unarmed. Model space, forward = -Z."], p)

# Chaos
p, a = chaos_jet("chs_harpy")
write("chs_harpy", ["Harpy (Chaos fighter, T1, footprint 1): a round fuselage on a big delta",
                    "wing with canards, one tall tail in team color, exposed engine pods with",
                    "orange glow; four cheap missiles on the belly `pylon`.",
                    "Model space, forward = -Z."], p, a)
p, a = chaos_jet("chs_manticore", length=7.8, span=7.4, pieces=("pylon", "turret"))
write("chs_manticore", ["Manticore (Chaos air superiority fighter, T2, footprint 1): a bigger",
                        "Harpy with a chin sensor `turret` (its heavy missiles turn it) and the",
                        "belly `pylon`; flare dispensers on the pods.",
                        "Model space, forward = -Z."], p + [
    part("flareL", "box", (0.3, 0.3, 0.8), (-1.45, 0.75, 2.4), "dark"),
    part("flareR", "box", (0.3, 0.3, 0.8), (1.45, 0.75, 2.4), "dark"),
], a)
p, a = chaos_jet("chs_plague", length=7.6, span=7.6, pieces=())
p.append(part("pylon", "box", (4.6, 0.25, 0.8), (0, 0.3, 1.4), "dark"))
a = bomber_parts(p, 7.6)
write("chs_plague", ["Plague (Chaos bomber, T1, footprint 1): the Chaos delta with a fat belly,",
                     "a bomb `bay` and an under-wing `pylon` rail for carpet bombs.",
                     "Model space, forward = -Z."], p, a)
p, a = chaos_jet("chs_behemoth", length=8.6, span=8.0, pieces=(), extra=(
    part("armorBelly", "box", (1.8, 0.4, 4.4), (0, 0.15, 0.2), "dark"),
    part("chaffL", "box", (0.4, 0.4, 1.0), (-1.6, 0.9, 2.6), "metal"),
    part("chaffR", "box", (0.4, 0.4, 1.0), (1.6, 0.9, 2.6), "metal"),
))
p.append(part("pylon", "box", (5.6, 0.25, 0.8), (0, 0.3, 1.6), "dark"))
a = bomber_parts(p, 8.6)
write("chs_behemoth", ["Behemoth (Chaos strategic bomber, T2, footprint 1): the biggest Chaos",
                       "delta, an armored belly, chaff boxes on the pods, a bomb `bay` and a",
                       "`pylon` rail. Model space, forward = -Z."], p, a)
p, a = chaos_jet("chs_banshee", length=7.4, span=7.0, pieces=())
p += [
    part("dish", "box", (2.6, 0.5, 2.2), (0, 1.7, 0.6), "dark"),
    part("dishGlow", "box", (2.2, 0.06, 1.8), (0, 1.97, 0.6), "glass", parent="dish"),
    part("podGlowL", "box", (0.12, 0.3, 1.2), (-1.4, 0.45, 2.4), "glass"),
    part("podGlowR", "box", (0.12, 0.3, 1.2), (1.4, 0.45, 2.4), "glass"),
]
write("chs_banshee", ["Banshee (Chaos EW jammer jet, T2, footprint 1): the Chaos delta with a",
                      "flat jammer `dish` box on the spine (a panel, never a dish), its top",
                      "glowing. Unarmed. Model space, forward = -Z."], p)

# --- helicopters ------------------------------------------------------------

def heli(uid, faction, comment, weapon=None, worker=False):
    order = faction == "order"
    p = []
    if order:
        p += [
            part("base", "box", (1.8, 1.5, 4.2), (0, 1.1, -0.4), "hull"),
            part("nose", "wedge", (1.8, 1.2, 1.4), (0, 0.95, -3.2), "hull"),
            part("canopy", "wedge", (1.4, 0.8, 1.4), (0, 1.8, -2.2), "glass"),
            part("boom", "box", (0.5, 0.5, 4.0), (0, 1.3, 3.6), "hull"),
            part("fin", "box", (0.15, 1.6, 0.9), (0, 2.0, 5.4), "team"),
            part("stabilizer", "box", (1.8, 0.12, 0.6), (0, 1.4, 5.0), "hull"),
            part("roofTeam", "box", (1.2, 0.06, 1.6), (0, 1.88, 0.4), "team"),
            part("skidL", "box", (0.15, 0.15, 4.4), (-0.9, 0.08, -0.4), "dark"),
            part("skidR", "box", (0.15, 0.15, 4.4), (0.9, 0.08, -0.4), "dark"),
        ]
    else:
        p += [
            part("base", "box", (1.6, 1.5, 3.8), (0, 1.2, -0.2), "hull"),
            part("nose", "ball", (1.6, 1.3, 1.6), (0, 1.1, -2.2), "glass"),
            part("boom", "box", (0.35, 0.35, 4.2), (0, 1.4, 3.8), "dark"),
            part("boomBrace", "box", (0.15, 0.15, 3.8), (0, 1.0, 3.6), "dark", rot=(-6, 0, 0)),
            part("fin", "box", (0.15, 1.8, 1.0), (0, 2.1, 5.7), "team"),
            part("engine", "cylinder", (0.9, 0.9, 1.8), (0, 2.25, 0.6), "metal", axis="z"),
            part("exhaust", "cylinder", (0.6, 0.6, 0.2), (0, 2.25, 1.6), "glass", axis="z"),
            part("deckTeam", "box", (1.2, 0.06, 1.2), (0, 1.98, -0.9), "team"),
            part("wheelL", "cylinder", (0.25, 0.6, 0.6), (-0.8, 0.3, -0.8), "track", axis="x"),
            part("wheelR", "cylinder", (0.25, 0.6, 0.6), (0.8, 0.3, -0.8), "track", axis="x"),
        ]
    top = 2.15 if order else 2.75
    p += [
        part("mast", "cylinder", (0.35, 0.6, 0.35), (0, top + 0.3, 0.2), "metal", axis="y"),
        part("rotor", "box", (8.6, 0.12, 0.45), (0, top + 0.65, 0.2), "dark"),
        part("blade2", "box", (0.45, 0.12, 8.6), (0, top + 0.65, 0.2), "dark", parent="rotor"),
        part("tailRotor", "cylinder", (0.12, 1.6, 1.6), (0.2, 2.0 if order else 2.1, 5.4 if order else 5.7), "dark", axis="x"),
    ]
    att = None
    if weapon == "pylon":
        p += [
            part("stubs", "box", (3.4, 0.2, 0.8), (0, 0.9, -0.4), "dark"),
            part("pylon", "box", (3.0, 0.5, 0.9), (0, 0.6, -0.4), "dark"),
            part("podL", "cylinder", (0.5, 0.5, 1.6), (-1.3, 0.55, -0.5), "metal", parent="pylon", axis="z"),
            part("podR", "cylinder", (0.5, 0.5, 1.6), (1.3, 0.55, -0.5), "metal", parent="pylon", axis="z"),
        ]
        att = [("muzzle", "pylon", (0, 0.55, -1.4))]
    elif weapon == "rack":
        p += [
            part("rack", "box", (2.6, 0.3, 1.0), (0, 0.55, 0.2), "dark"),
            part("torpL", "cylinder", (0.45, 0.45, 2.2), (-1.0, 0.35, 0.2), "metal", parent="rack", axis="z"),
            part("torpR", "cylinder", (0.45, 0.45, 2.2), (1.0, 0.35, 0.2), "metal", parent="rack", axis="z"),
            part("sonar", "cylinder", (0.7, 0.6, 0.7), (0, 0.2, -1.2), "glass"),
        ]
        att = [("muzzle", "rack", (0, 0.35, -0.9))]
    elif worker:
        p += [
            part("nano", "cylinder", (1.2, 0.3, 1.2), (0, 0.25, -0.2), "team", axis="y"),
            part("nanoArm", "box", (0.3, 0.3, 1.6), (0, 0.0, -0.9), "dark", parent="nano", rot=(20, 0, 0)),
            part("emitter", "ball", (0.7, 0.7, 0.7), (0, -0.3, -1.7), "glass", parent="nano"),
        ]
        if worker == "big":
            # T2: a cargo pod on the belly and a second emitter arm
            p += [
                part("cargo", "box", (1.4, 0.7, 2.0), (0, 0.25, 1.4), "dark"),
                part("nanoArm2", "box", (0.3, 0.3, 1.6), (0, 0.0, 0.5), "dark", parent="nano", rot=(-20, 0, 0)),
                part("emitter2", "ball", (0.6, 0.6, 0.6), (0, -0.3, 1.2), "glass", parent="nano"),
                part("podL", "box", (0.4, 0.6, 1.6), (-1.1, 1.0, 0.0), "hull"),
                part("podR", "box", (0.4, 0.6, 1.6), (1.1, 1.0, 0.0), "hull"),
            ]
    write(uid, comment, p, att, visual=["rotor"])


heli("ord_guardian", "order", ["Guardian (Order attack helicopter, T1, footprint 1): an armored boxy",
                               "cabin with a stepped canopy, a long boom and team fin, skids; rocket",
                               "pods on the `pylon` stub wings (the weapon turns it); the main",
                               "`rotor` is spun by the client (visual piece). Model space, forward = -Z."], weapon="pylon")
heli("ord_tidewatch", "order", ["Tidewatch (Order ASW helicopter, T2, footprint 1): the Order cabin with",
                                "a dipping-sonar dome under the nose and two torpedoes on the belly",
                                "`rack`; client-spun `rotor`. Model space, forward = -Z."], weapon="rack")
heli("ord_skywright", "order", ["Skywright (Order air builder, T1, footprint 1): the Order cabin with a",
                                "`nano` turret under the belly carrying a glowing emitter; client-spun",
                                "`rotor`. Model space, forward = -Z."], worker=True)
heli("ord_zenith", "order", ["Zenith (Order advanced air builder, T2, footprint 1): the Skywright's",
                             "airframe with side pods, a belly cargo pod and a second `nano`",
                             "emitter arm; client-spun `rotor`. Model space, forward = -Z."], worker="big")
heli("chs_wasp", "chaos", ["Wasp (Chaos attack helicopter, T1, footprint 1): a glass bubble nose, an",
                           "exposed engine with orange exhaust over the cabin, a lattice-braced boom",
                           "and team fin, wheels; rocket pods on the `pylon` stubs; client-spun",
                           "`rotor`. Model space, forward = -Z."], weapon="pylon")
heli("chs_leech", "chaos", ["Leech (Chaos ASW helicopter, T2, footprint 1): the Chaos airframe with",
                            "a sonar under the nose and two torpedoes on the `rack`; client-spun",
                            "`rotor`. Model space, forward = -Z."], weapon="rack")
heli("chs_vulture", "chaos", ["Vulture (Chaos air builder, T1, footprint 1): the Chaos airframe with a",
                              "`nano` emitter under the belly; client-spun `rotor`.",
                              "Model space, forward = -Z."], worker=True)
heli("chs_condor", "chaos", ["Condor (Chaos advanced air builder, T2, footprint 1): the Vulture's",
                             "airframe with side pods, a belly cargo pod and a second `nano`",
                             "emitter arm; client-spun `rotor`. Model space, forward = -Z."], worker="big")
print("ok")
