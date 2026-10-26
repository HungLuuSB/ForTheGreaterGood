"""Skitter (Chaos scout bot, T1, footprint 1; S-181; the fastest thing on
legs): mesh, textures, rig data.
blender -b --factory-startup --python-exit-code 1 -P assets/models/chs_skitter/build.py

From its approved blockout (2026-10-26): a low four-legged crawler. Big
shapes first: a dark body pod with a glowing ribbed abdomen and a team
plate, four splayed legs with knees high like a spider's, each a `thigh`
(hip to knee) and a `shin` (knee to a pointed foot) swinging for the
client's diagonal gait (`thighFL/FR/BL/BR`, `shinFL/..`; tools/animate.py
BOT4), and on top the `torso` (turns, the def's piece): a small armored
head with an amber eye slit, a spine fin and a plasma snout with a
glowing mouth (`muzzle`). Chaos reads crude (M-14). Writes export/ through
tools/unit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import bots  # noqa: E402
import lib  # noqa: E402
import unit  # noqa: E402
from mech import drum, rivets  # noqa: E402
from unit import UP, seam  # noqa: E402

HIP_R, HIP_Y = 0.9, 2.1
KNEE_R, KNEE_Y = 2.2, 2.9
FOOT_R, FOOT_Y = 2.7, 0.15
LEGS = {"FL": 225, "FR": 135, "BL": 315, "BR": 45}  # yaw of each leg, degrees
TORSO = (0.0, 2.45, 0.0)


def at(yaw, r, y):
    a = math.radians(yaw)
    return (math.sin(a) * r, y, math.cos(a) * r)


def beam(p, a, b, w, d, kind, bevel=0.03):
    a, b = lib.vec(a), lib.vec(b)
    n = (b - a).normalized()
    u = lib.vec((0, 1, 0)).cross(n)
    if u.length < 1e-6:
        u = lib.vec((1, 0, 0))
    u = u.normalized()
    p.obox(tuple((a + b) / 2), tuple(u), tuple(u.cross(n)), w, (b - a).length, d, kind, bevel=bevel)


def build_base(p):
    p.box((0, 2.0, 0), (1.8, 0.9, 2.4), "dark", bevel=0.08)
    p.box((0, 2.48, 0.4), (1.2, 0.05, 1.0), "team", bevel=0.01)
    p.box((0, 2.25, 1.75), (1.4, 1.0, 1.4), "paint", bevel=0.08)  # the abdomen
    for z in (1.35, 1.75, 2.15):
        p.box((0, 2.78, z), (1.0, 0.06, 0.18), "power")
    for yaw in LEGS.values():
        drum(p, at(yaw, HIP_R, HIP_Y), 0.24, 0.3, "steel", "trim", axis="y")


def details_base(p):
    rivets(p, (-0.7, 1.6, -1.21), (0.7, 1.6, -1.21), 4, (0, 0, -1))


def leg_specs(name, yaw):
    hip, knee, foot = at(yaw, HIP_R, HIP_Y), at(yaw, KNEE_R, KNEE_Y), at(yaw, FOOT_R, FOOT_Y)

    def thigh(p):
        beam(p, hip, knee, 0.34, 0.4, "paint", bevel=0.04)
        beam(p, at(yaw, HIP_R + 0.1, HIP_Y + 0.22), at(yaw, KNEE_R - 0.15, KNEE_Y + 0.22), 0.12, 0.12, "dark")
        drum(p, knee, 0.22, 0.4, "steel", "trim", axis="y")

    def shin(p):
        beam(p, knee, foot, 0.28, 0.32, "trim", bevel=0.03)
        p.ocyl(foot, (0, 1, 0), 0.18, 0.5, 6, "steel", radius2=0.06)
        p.box(at(yaw, KNEE_R + 0.15, KNEE_Y - 0.5), (0.12, 0.08, 0.12), "light")

    none = lambda p: None  # noqa: E731
    return [unit.PieceSpec(f"thigh{name}", "base", hip, thigh, none),
            unit.PieceSpec(f"shin{name}", f"thigh{name}", knee, shin, none)]


def build_torso(p):
    p.box((0, 2.85, -0.4), (1.3, 0.9, 1.6), "paint", bevel=0.1)
    p.box((0, 3.05, -1.22), (0.8, 0.16, 0.04), "head")
    p.box((0, 3.05, -1.24), (1.0, 0.36, 0.02), "dark")
    p.prism_x([(-0.8, 3.3), (0.4, 3.3), (0.2, 3.85)], -0.08, 0.08, "steel")  # spine fin
    p.ocyl((0, 2.7, -1.1), (0, 0, -1), 0.3, 1.2, 10, "steel")
    p.ocyl((0, 2.7, -1.6), (0, 0, -1), 0.36, 0.12, 10, "dark")
    p.ocyl((0, 2.7, -2.3), (0, 0, -1), 0.23, 0.04, 10, "weapon")


def details_torso(p):
    seam(p, (-0.65, 2.7, -0.9), (-0.65, 2.7, 0.3), (-1, 0, 0))


unit.run(__file__, "chs_skitter", "chaos", footprint=1,
         pieces=[unit.PieceSpec("base", None, (0.0, 0.0, 0.0), build_base, details_base),
                 unit.PieceSpec("torso", "base", TORSO, build_torso, details_torso)]
         + [s for name, yaw in LEGS.items() for s in leg_specs(name, yaw)],
         attachments={"muzzle": {"parent": "torso", "at": [0.0, 2.7, -2.45]}},
         budget=3000,
         previews=bots.previews(4.0))
