"""Goliath (Chaos main battle tank, T2; back in S-224): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_goliath/build.py

A hunched giant (re-modelled from scratch, 2026-10-30, the user): a wide
tracked hull with slat cages, a spiked ram and reactive-armor bricks; a
low, broad torso with a forward-thrust head (amber eye slits, two horns), a
team-painted roof, an ammo bustle and feed chutes to the shoulders. On tall
shoulder pylons hang the two gun arms, `armL` and `armR` (the def's pieces;
they raise to fire and recoil in turn, guide 14.4, S-20): a pauldron hood
over the elbow drum, an armored sleeve with reactive bricks and a team
stripe, a short heavy gun and a blocky muzzle brake with knuckle spikes. At rest
(pitch -65) the arms hang down beside the tracks with the knuckles just off
the ground, like a gorilla's. Muzzle rings on `weapon`, eyes and strips on
`running` (BAR style, M-15; Chaos reads open and brutal, M-14). Writes
export/ through tools/unit.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import hulls  # noqa: E402
import unit  # noqa: E402
from unit import UP, bolts  # noqa: E402

DECK = 2.4
TURRET = (0.0, DECK, 0.2)
SHOULDER_X, SHOULDER_Y, SHOULDER_Z = 4.0, 5.5, 0.2
ARM_L = (-SHOULDER_X, SHOULDER_Y, SHOULDER_Z)
ARM_R = (SHOULDER_X, SHOULDER_Y, SHOULDER_Z)
X = (1, 0, 0)


def build_base(p):
    d = hulls.tracked(p, "chaos", length=9.4, width=6.6, deck=DECK, track_w=0.9, wheels=7)
    # spiked ram across the nose
    p.prism_x([(-4.75, 0.55), (-5.45, 0.75), (-5.65, 1.55), (-4.75, 1.95)], -3.1, 3.1, "steel", bevel=0.05)
    p.box((0, 1.25, -5.62), (5.6, 0.12, 0.06), "hazard")
    for i in range(5):
        x = -2.4 + i * 1.2
        p.ocyl((x, 1.15, -5.55), (0, -0.15, -1), 0.22, 0.75, 6, "steel", radius2=0.02)
    # reactive bricks on the glacis
    for i in range(6):
        x = -2.5 + i * 1.0
        p.box((x, d - 0.25, -4.45), (0.85, 0.5, 0.18), "era", bevel=0.02)
    # turret ring, rear exhaust stacks with heat shields
    p.cylinder("y", (0, d + 0.08, 0.2), 2.3, 0.16, 16, "dark")
    for sx in (-1, 1):
        p.cylinder("y", (sx * 2.3, d + 0.9, 3.9), 0.26, 1.8, 10, "dark")
        p.cylinder("y", (sx * 2.3, d + 0.7, 3.9), 0.32, 1.0, 10, "steel")
        p.box((sx * 2.3, d + 1.83, 3.9), (0.5, 0.06, 0.5), "light")  # stack glow


def details_base(p):
    bolts(p, (-2.9, DECK + 0.001, -3.4), (2.9, DECK + 0.001, -3.4), 9, UP)
    bolts(p, (-2.4, DECK + 0.001, 4.2), (2.4, DECK + 0.001, 4.2), 7, UP)


def build_turret(p):
    # broad, low torso (sloped sides)
    p.prism_y([(-2.0, -2.2), (2.0, -2.2), (2.5, -1.2), (2.5, 2.4), (1.8, 3.2), (-1.8, 3.2), (-2.5, 2.4),
               (-2.5, -1.2)], DECK + 0.1, 4.9, "paint", bevel=0.06, top_scale=0.88)
    p.box((0, 4.93, 0.6), (3.0, 0.05, 2.8), "team", bevel=0.015)
    # forward-thrust head: brow, eye slits, horns
    p.prism_x([(-1.9, 3.3), (-3.1, 3.5), (-3.3, 4.3), (-2.9, 4.75), (-1.6, 4.85)], -1.0, 1.0, "paint", bevel=0.05)
    p.box((0, 4.82, -2.5), (1.5, 0.05, 0.9), "team", bevel=0.01)
    for sx in (-1, 1):
        p.obox((sx * 0.48, 4.05, -3.27), X, (0, 0.25, -1), 0.6, 0.16, 0.04, "light")  # eye slits
        p.ocyl((sx * 0.75, 4.6, -2.7), (sx * 0.45, 0.8, -0.4), 0.2, 1.0, 6, "steel", radius2=0.03)  # horns
    p.box((0, 3.65, -3.25), (1.6, 0.2, 0.1), "dark")  # chin grille
    # reactive bricks on the cheeks
    for sx in (-1, 1):
        for i in range(2):
            for j in range(2):
                p.box((sx * (1.35 + i * 0.7), 3.15 + j * 0.65, -2.27), (0.62, 0.55, 0.12), "era", bevel=0.02)
    # commander's cupola, sensor mast
    p.cylinder("y", (-1.0, 5.15, 1.4), 0.55, 0.45, 12, "trim")
    p.cylinder("y", (-1.0, 5.2, 1.4), 0.58, 0.14, 12, "glass")
    p.cylinder("y", (1.2, 5.6, 2.2), 0.07, 1.4, 6, "steel")
    p.box((1.2, 6.33, 2.2), (0.22, 0.14, 0.22), "light")
    # ammo bustle with a rear light bar
    p.box((0, 3.9, 3.55), (3.2, 1.4, 0.9), "paint", bevel=0.05)
    p.box((0, 3.9, 4.01), (2.8, 1.0, 0.04), "grille")
    p.box((0, 4.5, 4.02), (2.4, 0.12, 0.04), "light")
    for sx in (-1, 1):
        # feed chute from the bustle to the shoulder, side strip
        p.box((sx * 2.42, 4.35, 1.9), (0.22, 0.4, 2.6), "dark")
        p.box((sx * 2.5, 3.2, 0.4), (0.04, 0.16, 2.6), "light")
        # shoulder pylon and axle cap
        p.box((sx * 2.8, 4.9, SHOULDER_Z), (1.2, 1.6, 1.7), "paint", bevel=0.05)
        p.cylinder("x", (sx * 3.41, SHOULDER_Y, SHOULDER_Z), 0.62, 0.04, 14, "steel")


def build_arm(sx):
    def build(p):
        x, y = sx * SHOULDER_X, SHOULDER_Y
        x0, x1 = x - 0.55, x + 0.55
        # elbow drum on the shoulder axle
        p.cylinder("x", (x, y, SHOULDER_Z), 0.75, 1.1, 14, "paint", cap_kinds=("steel", "steel"))
        # pauldron: an armored hood over the drum, riding with the arm
        inner, outer = x - sx * 0.55, x + sx * 0.7  # flush inside, clear of the pylon
        p.prism_x([(1.15, y + 0.2), (-1.0, y + 0.35), (-0.8, y + 1.0), (0.95, y + 1.05)], min(inner, outer),
                  max(inner, outer), "paint", bevel=0.05)
        p.box((x, y + 1.04, 0.05), (0.8, 0.05, 1.4), "team", bevel=0.01)
        p.box((x + sx * 0.71, y + 0.62, 0.1), (0.04, 0.12, 1.6), "light")  # hood edge
        # armored sleeve, tapering underneath
        p.prism_x([(0.2, y - 0.6), (-2.9, y - 0.45), (-2.9, y + 0.5), (0.2, y + 0.55)], x0, x1, "paint", bevel=0.05)
        p.box((x, y + 0.56, -1.4), (0.6, 0.05, 2.2), "team", bevel=0.01)
        for z in (-0.6, -1.4, -2.2):
            p.box((x + sx * 0.6, y, z), (0.12, 0.7, 0.7), "era", bevel=0.02)
        p.box((x - sx * 0.57, y + 0.2, -1.4), (0.04, 0.14, 2.4), "light")  # inner strip
        # recoil sleeve and short heavy gun
        p.cylinder("z", (x, y, -3.3), 0.46, 0.8, 14, "trim")
        p.cylinder("z", (x, y, -4.1), 0.32, 1.0, 14, "trim")
        p.cylinder("z", (x, y, -4.0), 0.36, 0.1, 14, "weapon")
        # muzzle brake "fist" with knuckle spikes
        p.box((x, y, -5.0), (1.0, 0.9, 0.9), "dark", bevel=0.06)
        for side in (-1, 1):
            p.box((x + side * 0.51, y, -5.0), (0.04, 0.5, 0.5), "steel")  # brake ports
        p.cylinder("z", (x, y, -5.46), 0.26, 0.04, 12, "weapon")
        for kx in (-0.3, 0.3):
            p.ocyl((x + kx, y - 0.3, -5.45), (0, 0, -1), 0.13, 0.25, 6, "steel", radius2=0.02)
    return build


def no_details(p):
    pass


unit.run(__file__, "chs_goliath", "chaos", footprint=2,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("turret", "base", TURRET, build_turret, no_details),
                 unit.PieceSpec("armL", "turret", ARM_L, build_arm(-1), no_details),
                 unit.PieceSpec("armR", "turret", ARM_R, build_arm(1), no_details)],
         attachments={"muzzle": {"parent": "armR", "at": [SHOULDER_X, SHOULDER_Y, -5.5]}},
         budget=6000)
