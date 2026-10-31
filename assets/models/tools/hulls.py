"""Shared hulls for BAR-style ground units (tools/unit.py pieces): a tracked
hull and a wheeled hull, per faction look (Order heavy with skirts, Chaos
light with exposed running gear, M-14). Each draws into a piece builder
`p` and returns the hull's deck height, so the caller can place turrets
and team plates on it. Lights follow the glow rules: headlights on `head`,
running strips and tail lights on `light` (running channel).
"""

import math

import lib
from unit import wheel


def tracked(p, faction, length=8.0, width=6.0, deck=1.9, track_w=0.8, wheels=6):
    """Hull centred on the origin, forward = -Z. Returns the deck height."""
    hl, hw = length / 2, width / 2
    tx = hw - track_w / 2  # track centre x
    order = faction == "order"
    # lower hull between the tracks, sloped front
    p.prism_x([(-hl + 0.6, 0.45), (hl - 0.3, 0.45), (hl, 0.85), (hl, deck - 0.5), (-hl, deck - 0.5)],
              -(hw - track_w), hw - track_w, "trim", bevel=0.03)
    # upper hull over the tracks with a glacis
    p.prism_x([(-hl - 0.2, deck - 0.6), (hl, deck - 0.6), (hl, deck - 0.1), (hl - 0.2, deck), (-hl + 1.8, deck),
               (-hl - 0.2, deck - 0.45)], -hw, hw, "paint", bevel=0.05)
    # tracks: a band round sprocket and idler, road wheels
    outline = [(-hl + 0.7, 0.0), (hl - 0.5, 0.0)]
    outline += lib.outline_circle(hl - 0.5, 0.5, 0.5, -90, 90, 8)[1:]
    outline += [(-hl + 0.4, 1.0)]
    outline += lib.outline_circle(-hl + 0.4, 0.6, 0.4, 90, 210, 5)[1:]
    inner = lib.offset_polygon(outline, 0.1)
    for sx in (-1, 1):
        x0, x1 = (tx - track_w / 2, tx + track_w / 2)
        if sx < 0:
            x0, x1 = -x1, -x0
        with p.sub("trackL" if sx < 0 else "trackR", (sx * tx, 0.46, 0.0), "scroll", (1, 0, 0)):  # M-27
            p.band_x(outline, inner, x0, x1, "track")
            for i in range(wheels):
                z = -hl + 1.0 + i * (length - 2.0) / (wheels - 1)
                p.cylinder("x", (sx * tx, 0.46, z), 0.4, track_w * 0.5, 10, "rubber", cap_kinds=("trim", "trim"))
        if order:  # thick skirts with a team strip and a running strip
            p.box((sx * (hw + 0.13), deck - 0.65, 0.2), (0.24, 1.0, length - 0.8), "paint", bevel=0.04)
            p.box((sx * (hw + 0.26), deck - 0.6, 0.4), (0.04, 0.32, length * 0.45), "team", bevel=0.01)
            p.box((sx * (hw + 0.26), deck - 0.22, 0.2), (0.04, 0.14, length - 1.4), "light")
        else:  # slat cage over the exposed wheels
            p.box((sx * (hw + 0.05), deck - 0.4, 0.2), (0.08, 0.1, length - 1.0), "steel")
            for i in range(5):
                z = -hl + 1.2 + i * (length - 2.4) / 4
                p.box((sx * (hw + 0.05), deck - 0.8, z), (0.08, 0.8, 0.08), "steel")
            p.box((sx * (hw - 0.3), deck + 0.01, 0.4), (0.6, 0.04, length * 0.4), "team", bevel=0.01)
            p.box((sx * (hw + 0.1), deck - 0.4, 0.2), (0.04, 0.12, length - 1.6), "light")
        p.box((sx * (hw - 0.8), deck - 0.35, -hl - 0.05), (0.6, 0.2, 0.1), "head")
        p.box((sx * (hw - 0.6), deck - 0.35, hl + 0.03), (0.5, 0.16, 0.06), "light")
    p.box((0, deck - 0.75, -hl - 0.18), (width * 0.55, 0.12, 0.06), "light")  # glacis light bar
    p.box((0, deck + 0.02, hl - 0.9), (width * 0.45, 0.05, 1.0), "grille")
    for i in range(3):
        p.box((0, deck + 0.04, hl - 1.25 + i * 0.35), (width * 0.4, 0.04, 0.18), "light")  # exhaust slots
    return deck


def amphibious(p, faction, length=7.0, width=4.8, deck=1.9, wheels=5):
    """Amphibious tracked hull (batch 1 of the BAR roster): the tracked hull
    with a raised boat bow, flotation sponsons along the sides (team-banded on
    Order, open-framed on Chaos), a snorkel and a stern water-jet grille.
    Forward = -Z. Returns the deck height."""
    d = tracked(p, faction, length=length, width=width, deck=deck, wheels=wheels)
    hl, hw = length / 2, width / 2
    order = faction == "order"
    # the boat bow: a raked prow over the glacis
    p.prism_x([(-hl - 0.9, d - 0.55), (-hl - 0.2, d - 1.25), (-hl + 0.6, d - 1.1), (-hl + 0.9, d + 0.05),
               (-hl - 0.5, d - 0.1)], -hw + 0.5, hw - 0.5, "paint", bevel=0.05)
    p.box((0, d - 0.35, -hl - 0.72), (width * 0.5, 0.1, 0.05), "light")
    for sx in (-1, 1):
        x = sx * (hw + 0.32)
        p.cylinder("z", (x, d - 0.55, 0.3), 0.42, length - 1.6, 10, "paint" if order else "dark",
                   cap_kinds=("trim", "trim"), radius2=0.42)
        p.ocyl((x, d - 0.55, -hl + 0.5), (0, 0, -1), 0.42, 0.5, 10, "trim", radius2=0.12)  # nose cone
        if order:
            p.cylinder("z", (x, d - 0.55, 0.3), 0.44, 0.5, 10, "team")
        else:
            for z in (-1.4, 0.6, 2.4):
                p.box((x - sx * 0.3, d - 0.3, z), (0.5, 0.1, 0.12), "steel")  # open brackets
    p.cylinder("y", (hw * 0.55, d + 0.75, hl - 0.8), 0.16, 1.5, 8, "trim")  # snorkel
    p.box((hw * 0.55, d + 1.55, hl - 0.8), (0.4, 0.14, 0.4), "dark")
    p.box((0, d - 0.9, hl + 0.06), (width * 0.4, 0.5, 0.06), "grille")  # water jets
    return d


def hover(p, faction, length=7.0, width=5.0, deck=1.6, fans=2):
    """Hovercraft hull (batch 1): a dark rubber skirt all round, a low hull on
    it with a raked prow, lift fans in ducts at the stern (sub-pieces that
    spin, M-27), rudder fins, headlights and running strips. Forward = -Z.
    Returns the deck height."""
    hl, hw = length / 2, width / 2
    order = faction == "order"
    # the skirt: a rounded rubber cushion round the hull's foot
    skirt = [(-hl - 0.3, 0.1), (hl + 0.1, 0.1), (hl + 0.3, 0.45), (hl + 0.1, 0.85), (-hl - 0.1, 0.85), (-hl - 0.5, 0.45)]
    p.prism_x(skirt, -hw, hw, "rubber", bevel=0.08)
    p.prism_x([(-hl + 0.1, 0.85), (hl - 0.1, 0.85), (hl - 0.1, deck), (-hl + 1.4, deck), (-hl - 0.2, deck - 0.6)],
              -hw + 0.25, hw - 0.25, "paint", bevel=0.05)
    p.box((0, 0.88, 0), (width - 0.2, 0.06, length - 0.2), "trim")  # the skirt's top rim
    for i in range(fans):
        x = 0 if fans == 1 else (-1 + 2 * i / (fans - 1)) * hw * 0.5
        r = min(hw * 0.38, 1.1) if fans > 1 else hw * 0.42
        z = hl - r - 0.2
        p.cylinder("y", (x, deck + 0.3, z), r + 0.12, 0.6, 14, "trim", cap_kinds=("dark", "dark"))  # duct
        with p.sub(f"fan{i + 1}", (x, deck + 0.62, z), "spin", (0, 1, 0)):
            for k in range(3):
                a = k * 2.094
                p.obox((x, deck + 0.62, z), (math.cos(a), 0, math.sin(a)), (0, 1, 0), r * 1.9, 0.18, 0.05, "steel")
            p.cylinder("y", (x, deck + 0.62, z), r * 0.2, 0.12, 8, "dark")
    for sx in (-1, 1):
        p.box((sx * hw * 0.42, deck + 0.75, hl - 0.2), (0.1, 1.0, 0.7), "paint" if order else "dark", bevel=0.02)  # rudders
        p.box((sx * (hw - 0.26), deck - 0.4, 0.2), (0.04, 0.12, length - 2.0), "light")
        p.box((sx * (hw - 0.8), deck - 0.4, -hl - 0.05), (0.5, 0.18, 0.08), "head")
        if order:
            p.box((sx * (hw - 0.5), deck + 0.02, -0.6), (0.6, 0.04, length * 0.35), "team", bevel=0.01)
        else:
            p.box((sx * (hw + 0.02), 0.55, 0.0), (0.08, 0.1, length - 1.2), "steel")  # skirt rail
            p.box((sx * (hw - 0.3), deck + 0.01, -0.4), (0.5, 0.04, length * 0.3), "team", bevel=0.01)
    return deck


def wheeled(p, faction, length=7.6, width=5.0, deck=2.2, axles=3):
    """A wheeled (6 x 6 by default) hull, forward = -Z. Returns the deck height."""
    hl, hw = length / 2, width / 2
    order = faction == "order"
    p.prism_x([(-hl - 0.3, 1.2), (-hl + 0.9, 0.8), (hl, 0.8), (hl, deck), (-hl + 1.4, deck), (-hl - 0.3, 1.6)],
              -hw + 0.4, hw - 0.4, "paint", bevel=0.06)
    for sx in (-1, 1):
        for i in range(axles):
            z = -hl + 1.4 + i * (length - 2.6) / max(1, axles - 1)
            wheel(p, sx * (hw - 0.2), 0.75, z, 0.75, 0.6, name=f"wheel{'L' if sx < 0 else 'R'}{i + 1}")
        if order:
            p.prism_x([(-hl + 0.6, 1.25), (hl - 0.2, 1.25), (hl - 0.2, 1.9), (-hl + 0.6, 1.9)],
                      *((hw - 0.4, hw - 0.05) if sx > 0 else (-hw + 0.05, -hw + 0.4)), "paint", bevel=0.03)
            p.box((sx * (hw - 0.02), 1.6, 0.0), (0.05, 0.32, length * 0.45), "team", bevel=0.012)
        else:
            p.box((sx * (hw - 0.35), deck + 0.01, 0.3), (0.6, 0.04, length * 0.35), "team", bevel=0.01)
        p.box((sx * (hw - 0.38), 1.95, 0.0), (0.05, 0.14, length - 1.6), "light")
        p.box((sx * (hw - 1.0), 1.25, -hl - 0.33), (0.55, 0.2, 0.08), "head")
        p.box((sx * (hw - 0.9), 1.6, hl + 0.03), (0.45, 0.16, 0.06), "light")
    return deck
