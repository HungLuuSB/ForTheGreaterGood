"""Shared hulls for BAR-style ground units (tools/unit.py pieces): a tracked
hull and a wheeled hull, per faction look (Order heavy with skirts, Chaos
light with exposed running gear, M-14). Each draws into a piece builder
`p` and returns the hull's deck height, so the caller can place turrets
and team plates on it. Lights follow the glow rules: headlights on `head`,
running strips and tail lights on `light` (running channel).
"""

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
