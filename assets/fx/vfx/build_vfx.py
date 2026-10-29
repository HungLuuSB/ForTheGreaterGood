"""Particle templates for the client's Render/Vfx (C-47; F27, the user's
beta feedback 2026-10-26: "Shot does not look powerful enough ... Push the
limit"). Writes place/Vfx.model.json, which Rojo puts in ReplicatedStorage
as `Vfx` (default/serve/build project files), where Render/Vfx looks up a
template by name on every burst (Vfx.TEMPLATE_NAMES).

    python assets/fx/vfx/build_vfx.py

`Death` (every unit's death, and the blast burst drawn with it, C-232):
the user's reference assets/reference/unit_explosion (a ground burst):
a white-hot flash, a rolling fireball, a ring of fire racing out along the
ground, long sparks streaking up and out, dark debris thrown in arcs,
black smoke billowing up through it, glowing embers drifting and a
glowing scorch fading on the ground, an orange light. Authored at scale 1
= a 7-stud explosion (the client scales sizes and speeds by the burst's
diameter / 7, capped at 6). Played upright (deaths carry no direction).

The Commander D-Gun (S-194; the user via clients-B 2026-10-30, "make the
VFX for D-gun too"): a slow plasma bolt, 70 studs/s, riding 5 studs over the
ground for 80 studs, destroying everything within 7 studs either side, no
wreck. Its colour is fixed for both factions, fx.color (255, 200, 90), hot
orange-white, not tinted at runtime. Authored at real size (a 14-stud-wide
path, the bolt about 7 studs across), so scale 1 draws it as the sim sees it.
- `DgunBolt`: the travelling bolt, a Folder of two Attachments: `Bolt` at the
  carrier (a white-hot core and plasma held on the bolt, a heat trail and
  sparks left behind in world space, an orange light) and `Ground`, 5 studs
  below it (fire, a glowing scorch and smoke left along the path). Its
  emitters are saved Enabled with a `Rate` and no `EmitCount`; the template's
  `Continuous` attribute says so: they run while the client moves the bolt,
  and the light stays on. The client stops them at the end of the path.
- `DgunMuzzle`: the launch flash at the barrel, facing the shot (-Z).
- `DgunHit`: the short burst on each unit it burns through (frequent: kept small).
- `DgunEnd`: the fizzle where it runs out of range: a flash, a small fireball,
  a ring of plasma along the ground, sparks, smoke, embers and a scorch.

Per emitter: `EmitCount` (Emit once), `EmitDelay` (seconds after the
burst); per light: `LightSeconds`. Built-in Studio particle textures only.
"""

import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
OUT = os.path.join(ROOT, "place", "Vfx.model.json")

TEX = {
    "fire": "rbxasset://textures/particles/fire_main.dds",
    "sparks": "rbxasset://textures/particles/fire_sparks_main.dds",
    "smoke": "rbxasset://textures/particles/smoke_main.dds",
    "core": "rbxasset://textures/particles/explosion01_core_main.dds",
    "shock": "rbxasset://textures/particles/explosion01_shockwave_main.dds",
    "puff": "rbxasset://textures/particles/explosion01_smoke_main.dds",
    "sparkle": "rbxasset://textures/particles/sparkles_main.dds",
    "square": "rbxasset://textures/particles/SquareParticle.png",
}

# Enum values (Roblox API)
TOP, FRONT = 1, 5  # NormalId: Top, Front
FACING, VEL_PARALLEL, VEL_PERP = 0, 1, 2  # ParticleOrientation


def ns(*points):
    """NumberSequence from (time, value[, envelope]) points."""
    return {"NumberSequence": {"keypoints": [{"time": p[0], "value": p[1], "envelope": p[2] if len(p) > 2 else 0} for p in points]}}


def cs(*points):
    """ColorSequence from (time, (r, g, b) 0..255) points."""
    return {"ColorSequence": {"keypoints": [{"time": t, "color": [c[0] / 255, c[1] / 255, c[2] / 255]} for t, c in points]}}


def rng(a, b):
    return {"NumberRange": [a, b]}


def emitter(name, tex, count, life, speed, size, color, transparency, *, delay=0.0, direction=TOP, spread=(180, 180),
            accel=(0, 0, 0), drag=0.0, light_emission=0.0, light_influence=0.0, orientation=FACING, rotation=(0, 360),
            rot_speed=(-60, 60), squash=None, zoffset=0.0, brightness=1.0, rate=0, locked=False):
    """`count` emits once; `rate` > 0 instead runs continuously (saved Enabled,
    no EmitCount: the D-Gun bolt). `locked` keeps the particles on the rig."""
    props = {
        "Texture": tex,
        "Lifetime": rng(*life),
        "Speed": rng(*speed),
        "Size": size,
        "Color": color,
        "Transparency": transparency,
        "EmissionDirection": {"Enum": direction},
        "SpreadAngle": {"Vector2": list(spread)},
        "Acceleration": {"Vector3": list(accel)},
        "Drag": drag,
        "LightEmission": light_emission,
        "LightInfluence": light_influence,
        "Orientation": {"Enum": orientation},
        "Rotation": rng(*rotation),
        "RotSpeed": rng(*rot_speed),
        "ZOffset": zoffset,
        "Brightness": brightness,
        "Rate": rate,
        "Enabled": rate > 0,
        "LockedToPart": locked,
    }
    if squash is not None:
        props["Squash"] = squash
    attrs = {} if rate > 0 else {"EmitCount": count, "EmitDelay": delay}
    return {"Name": name, "ClassName": "ParticleEmitter", "Properties": props, "Attributes": attrs}


def light(color, range_, brightness, seconds=None, on=False):
    """A PointLight: flashes and fades over `seconds`, or (`on`) stays lit while a continuous rig runs."""
    out = {"Name": "Light", "ClassName": "PointLight",
           "Properties": {"Color": {"Color3": [c / 255 for c in color]}, "Range": range_, "Brightness": brightness,
                          "Shadows": False, "Enabled": on}}
    if seconds is not None:
        out["Attributes"] = {"LightSeconds": seconds}
    return out


HOT = (255, 246, 214)
YELLOW = (255, 214, 120)
ORANGE = (255, 140, 48)
RED = (196, 52, 18)
EMBER = (255, 120, 40)
SOOT = (34, 30, 28)

DEATH = [
    # the white-hot flash at the heart
    emitter("Flash", TEX["core"], 3, (0.16, 0.22), (0, 0), ns((0, 1.2), (0.3, 5.0), (1, 6.0)),
            cs((0, HOT), (0.4, YELLOW), (1, ORANGE)), ns((0, 0), (0.5, 0.25), (1, 1)), light_emission=1, brightness=1.4, zoffset=1),
    # the rolling fireball
    emitter("Fireball", TEX["fire"], 22, (0.45, 0.85), (3, 9), ns((0, 2.0, 0.6), (0.35, 3.6, 0.8), (1, 1.2)),
            cs((0, YELLOW), (0.3, ORANGE), (0.7, RED), (1, (90, 30, 14))), ns((0, 0), (0.6, 0.15), (1, 1)),
            accel=(0, 5, 0), drag=3.0, light_emission=0.6, rot_speed=(-140, 140), brightness=1.1),
    # the ring of fire racing out along the ground
    emitter("FireRing", TEX["fire"], 64, (0.4, 0.6), (16, 20), ns((0, 1.0), (0.3, 2.2, 0.4), (1, 0.6)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.1), (0.7, 0.3), (1, 1)),
            direction=FRONT, spread=(0, 180), accel=(0, 2, 0), drag=3.5, light_emission=0.8, brightness=1.2),
    # fire still burning low in the middle as the smoke rises
    emitter("Burn", TEX["fire"], 14, (0.5, 0.9), (1, 3), ns((0, 1.2, 0.3), (0.4, 2.0), (1, 0.4)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.2), (0.6, 0.3), (1, 1)),
            delay=0.25, spread=(40, 40), accel=(0, 6, 0), drag=1.0, light_emission=0.7, rot_speed=(-90, 90)),
    # long sparks streaking up and out
    # (solid streaks: the square texture stretched along the velocity; fire_sparks reads too faint at RTS range)
    emitter("Sparks", TEX["square"], 46, (0.45, 0.9), (18, 30), ns((0, 0.16), (1, 0.05)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0), (0.8, 0.2), (1, 1)),
            spread=(55, 55), accel=(0, -32, 0), drag=1.0, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.5), (1, -1.2)), brightness=1.4),
    # dark debris thrown in arcs
    emitter("Debris", TEX["square"], 14, (0.8, 1.2), (10, 18), ns((0, 0.18, 0.06), (1, 0.12)),
            cs((0, (60, 54, 50)), (1, (30, 28, 26))), ns((0, 0), (0.85, 0), (1, 1)),
            spread=(70, 70), accel=(0, -42, 0), drag=0.6, light_influence=1, rot_speed=(-360, 360)),
    # black smoke billowing up through the fire
    emitter("Smoke", TEX["smoke"], 18, (1.8, 2.8), (3, 7), ns((0, 2.4, 0.5), (0.4, 5.0, 0.9), (1, 7.0)),
            cs((0, (92, 70, 54)), (0.3, (52, 46, 42)), (1, (40, 38, 36))), ns((0, 0.5), (0.25, 0.3), (0.7, 0.55), (1, 1)),
            delay=0.12, spread=(65, 65), accel=(0, 5, 0), drag=1.2, light_influence=1, rot_speed=(-40, 40)),
    # glowing embers drifting up afterwards
    emitter("Embers", TEX["sparkle"], 26, (1.6, 2.8), (2, 6), ns((0, 0.3), (1, 0.08)),
            cs((0, YELLOW), (1, EMBER)), ns((0, 0), (0.7, 0.3), (1, 1)),
            delay=0.15, spread=(80, 80), accel=(0, 2, 0), drag=1.5, light_emission=1, brightness=1.5),
    # the glowing scorch fading on the ground (flat: faces its upward velocity)
    emitter("Scorch", TEX["shock"], 2, (1.6, 2.0), (0.01, 0.01), ns((0, 4.0), (0.2, 5.6), (1, 6.0)),
            cs((0, ORANGE), (0.4, RED), (1, (40, 20, 10))), ns((0, 0.1), (0.5, 0.4), (1, 1)),
            spread=(0, 0), orientation=VEL_PERP, light_emission=0.7, rotation=(0, 360), rot_speed=(0, 0), zoffset=-1),
    {"Name": "Light", "ClassName": "PointLight",
     "Properties": {"Color": {"Color3": [1.0, 0.62, 0.3]}, "Range": 18, "Brightness": 7, "Shadows": False, "Enabled": False},
     "Attributes": {"LightSeconds": 0.55}},
]


# The D-Gun's fixed colour (fx.color) and its hotter and cooler ends
DG = (255, 200, 90)
DG_HOT = (255, 248, 226)
DG_DEEP = (255, 120, 30)
DG_DARK = (150, 40, 12)

DGUN_BOLT = [
    # the white-hot core, held on the bolt: about 7 studs across, so the 14-stud path reads
    emitter("Core", TEX["core"], 0, (0.12, 0.18), (0, 0), ns((0, 6.0, 0.4), (0.5, 7.5), (1, 6.5)),
            cs((0, DG_HOT), (0.25, DG), (1, DG)), ns((0, 0), (0.7, 0.1), (1, 1)),
            light_emission=1, brightness=2.6, zoffset=2, rate=60, locked=True),
    # the plasma churning round it, also held on the bolt
    emitter("Plasma", TEX["fire"], 0, (0.16, 0.26), (0.5, 2), ns((0, 4.5, 0.8), (0.5, 6.0), (1, 2.4)),
            cs((0, DG_HOT), (0.3, DG), (1, DG_DEEP)), ns((0, 0), (0.6, 0.15), (1, 1)),
            light_emission=1, rot_speed=(-300, 300), brightness=3, zoffset=1, rate=90, locked=True),
    # the outer glow: a soft halo a little wider than the bolt
    emitter("Halo", TEX["shock"], 0, (0.12, 0.18), (0, 0), ns((0, 8.0), (1, 9.5)),
            cs((0, DG), (1, DG_DEEP)), ns((0, 0.35), (1, 1)),
            light_emission=1, rot_speed=(-90, 90), brightness=2, rate=24, locked=True),
    # the heat trail left behind in world space (at 70 studs/s, about 25 studs long)
    emitter("Trail", TEX["fire"], 0, (0.4, 0.6), (0, 1), ns((0, 5.0, 0.6), (0.4, 3.6), (1, 0.8)),
            cs((0, DG_HOT), (0.2, DG), (0.5, DG_DEEP), (0.85, DG_DARK), (1, (70, 24, 10))), ns((0, 0.05), (0.6, 0.3), (1, 1)),
            light_emission=1, rot_speed=(-120, 120), brightness=2.2, rate=130),
    # sparks shed sideways and up
    emitter("Sparks", TEX["square"], 0, (0.3, 0.6), (8, 16), ns((0, 0.14), (1, 0.04)),
            cs((0, DG_HOT), (0.4, DG), (1, DG_DEEP)), ns((0, 0), (0.8, 0.3), (1, 1)),
            spread=(80, 80), accel=(0, -24, 0), drag=1.5, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.0), (1, -1.0)), brightness=2.5, rate=60),
    light(DG, 18, 4, on=True),
]
DGUN_GROUND = [
    # fire left burning along the path, under the bolt
    emitter("GroundFire", TEX["fire"], 0, (1.2, 2.0), (1, 5), ns((0, 2.2, 0.6), (0.3, 3.4, 0.6), (1, 0.8)),
            cs((0, DG), (0.3, DG_DEEP), (0.8, DG_DARK), (1, (60, 20, 8))), ns((0, 0.05), (0.6, 0.25), (1, 1)),
            spread=(85, 85), accel=(0, 4, 0), drag=2.5, light_emission=1, rot_speed=(-80, 80), brightness=2, rate=70),
    # a glowing scorch streak fading on the ground (flat: faces its upward velocity; soft blobs that
    # overlap into one strip, where the shockwave texture read as a row of rings)
    emitter("Scorch", TEX["core"], 0, (2.5, 3.5), (0.01, 0.01), ns((0, 6.0), (0.15, 7.5), (1, 8.0)),
            cs((0, DG_DEEP), (0.2, DG_DARK), (0.5, (40, 20, 12)), (1, (24, 16, 12))), ns((0, 0.05), (0.6, 0.3), (1, 1)),
            spread=(0, 0), orientation=VEL_PERP, light_emission=0.3, rot_speed=(0, 0), zoffset=-1, rate=18),
    # smoke rising off the burnt strip
    emitter("Smoke", TEX["smoke"], 0, (1.4, 2.2), (2, 4), ns((0, 2.0, 0.4), (1, 5.0)),
            cs((0, (80, 60, 46)), (1, (44, 40, 38))), ns((0, 0.55), (0.3, 0.45), (1, 1)),
            spread=(30, 30), accel=(0, 3, 0), drag=1.0, light_influence=1, rot_speed=(-30, 30), rate=10),
]
DGUN_MUZZLE = [
    emitter("Flash", TEX["core"], 3, (0.1, 0.14), (0, 0), ns((0, 2.5), (0.4, 7.0), (1, 8.0)),
            cs((0, DG_HOT), (0.5, DG), (1, DG_DEEP)), ns((0, 0), (0.5, 0.2), (1, 1)), light_emission=1, brightness=4, zoffset=1),
    # the plasma jet blown out along the shot
    emitter("Jet", TEX["fire"], 22, (0.18, 0.32), (22, 38), ns((0, 2.2, 0.5), (0.4, 2.8), (1, 0.6)),
            cs((0, DG_HOT), (0.3, DG), (1, DG_DEEP)), ns((0, 0), (0.6, 0.25), (1, 1)),
            direction=FRONT, spread=(22, 22), drag=5, light_emission=1, rot_speed=(-200, 200), brightness=3),
    # a shock ring across the barrel's mouth (flat: faces its velocity along the shot)
    emitter("Ring", TEX["shock"], 1, (0.18, 0.22), (0.01, 0.01), ns((0, 2.0), (1, 9.0)),
            cs((0, DG_HOT), (1, DG)), ns((0, 0.1), (1, 1)), direction=FRONT, spread=(0, 0),
            orientation=VEL_PERP, light_emission=1, rot_speed=(0, 0), brightness=1.5),
    emitter("Sparks", TEX["square"], 18, (0.25, 0.45), (30, 50), ns((0, 0.14), (1, 0.04)),
            cs((0, DG_HOT), (1, DG_DEEP)), ns((0, 0), (0.8, 0.3), (1, 1)),
            direction=FRONT, spread=(28, 28), accel=(0, -20, 0), drag=2, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.5), (1, -1.2)), brightness=1.5),
    emitter("Smoke", TEX["puff"], 6, (0.8, 1.2), (3, 7), ns((0, 1.5, 0.3), (1, 4.5)),
            cs((0, (110, 90, 70)), (1, (60, 56, 52))), ns((0, 0.4), (0.4, 0.55), (1, 1)),
            delay=0.05, direction=FRONT, spread=(40, 40), accel=(0, 3, 0), drag=2, light_influence=1, rot_speed=(-40, 40)),
    light(DG, 16, 5, seconds=0.22),
]
DGUN_HIT = [
    emitter("Flash", TEX["core"], 2, (0.1, 0.14), (0, 0), ns((0, 2.0), (0.4, 5.0), (1, 5.5)),
            cs((0, DG_HOT), (1, DG)), ns((0, 0), (0.5, 0.2), (1, 1)), light_emission=1, brightness=3.5, zoffset=1),
    emitter("Burst", TEX["fire"], 10, (0.2, 0.32), (8, 14), ns((0, 1.8, 0.4), (0.4, 2.4), (1, 0.5)),
            cs((0, DG_HOT), (0.3, DG), (1, DG_DARK)), ns((0, 0), (0.6, 0.3), (1, 1)),
            drag=4, light_emission=1, rot_speed=(-200, 200), brightness=2.5),
    emitter("Sparks", TEX["square"], 12, (0.25, 0.5), (16, 28), ns((0, 0.12), (1, 0.04)),
            cs((0, DG_HOT), (1, DG_DEEP)), ns((0, 0), (0.8, 0.3), (1, 1)),
            spread=(70, 70), accel=(0, -30, 0), drag=1.5, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.2), (1, -1.0)), brightness=1.5),
    light(DG, 12, 4, seconds=0.15),
]
DGUN_END = [
    emitter("Flash", TEX["core"], 3, (0.16, 0.22), (0, 0), ns((0, 2.0), (0.3, 7.0), (1, 8.0)),
            cs((0, DG_HOT), (0.4, DG), (1, DG_DEEP)), ns((0, 0), (0.5, 0.2), (1, 1)), light_emission=1, brightness=3.5, zoffset=1),
    emitter("Fireball", TEX["fire"], 16, (0.4, 0.7), (3, 7), ns((0, 2.0, 0.5), (0.35, 3.2, 0.6), (1, 1.0)),
            cs((0, DG_HOT), (0.25, DG), (0.7, DG_DEEP), (1, DG_DARK)), ns((0, 0), (0.6, 0.2), (1, 1)),
            accel=(0, 6, 0), drag=3, light_emission=1, rot_speed=(-140, 140), brightness=2.5),
    # the plasma spilling out in a ring along the ground (played level, so FRONT swept round Y is horizontal)
    emitter("Ring", TEX["fire"], 40, (0.35, 0.55), (14, 18), ns((0, 1.2), (0.3, 2.2, 0.4), (1, 0.5)),
            cs((0, DG), (0.4, DG_DEEP), (1, DG_DARK)), ns((0, 0.1), (0.7, 0.3), (1, 1)),
            direction=FRONT, spread=(0, 180), accel=(0, 2, 0), drag=3.5, light_emission=1, brightness=2.5),
    emitter("Sparks", TEX["square"], 24, (0.4, 0.8), (14, 24), ns((0, 0.14), (1, 0.05)),
            cs((0, DG_HOT), (0.4, DG), (1, DG_DEEP)), ns((0, 0), (0.8, 0.2), (1, 1)),
            spread=(50, 50), accel=(0, -32, 0), drag=1, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.5), (1, -1.2)), brightness=1.5),
    emitter("Smoke", TEX["smoke"], 8, (1.4, 2.2), (2, 5), ns((0, 2.0, 0.4), (0.4, 4.0), (1, 5.5)),
            cs((0, (90, 68, 50)), (0.3, (52, 46, 42)), (1, (40, 38, 36))), ns((0, 0.5), (0.3, 0.35), (1, 1)),
            delay=0.1, spread=(50, 50), accel=(0, 4, 0), drag=1.2, light_influence=1, rot_speed=(-40, 40)),
    emitter("Embers", TEX["sparkle"], 14, (1.2, 2.2), (2, 5), ns((0, 0.3), (1, 0.08)),
            cs((0, DG), (1, DG_DEEP)), ns((0, 0), (0.7, 0.3), (1, 1)),
            delay=0.12, spread=(80, 80), accel=(0, 2, 0), drag=1.5, light_emission=1, brightness=1.5),
    emitter("Scorch", TEX["shock"], 1, (1.6, 2.2), (0.01, 0.01), ns((0, 3.5), (0.2, 6.0), (1, 6.5)),
            cs((0, DG_DEEP), (0.4, DG_DARK), (1, (30, 16, 10))), ns((0, 0.1), (0.5, 0.4), (1, 1)),
            spread=(0, 0), orientation=VEL_PERP, light_emission=0.7, rot_speed=(0, 0), zoffset=-1),
    light(DG, 18, 5, seconds=0.45),
]


def template(name, children, attributes=None):
    out = {"Name": name, "ClassName": "Attachment", "Children": children}
    if attributes:
        out["Attributes"] = attributes
    return out


def attachment(name, children, at=(0, 0, 0)):
    return {"Name": name, "ClassName": "Attachment", "Children": children,
            "Properties": {"CFrame": {"CFrame": {"position": list(at), "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}}}


def main():
    bolt = {"Name": "DgunBolt", "ClassName": "Folder", "Attributes": {"Continuous": True},
            "Children": [attachment("Bolt", DGUN_BOLT), attachment("Ground", DGUN_GROUND, (0, -5, 0))]}
    model = {"ClassName": "Folder", "Children": [
        template("Death", DEATH),
        bolt,
        template("DgunMuzzle", DGUN_MUZZLE),
        template("DgunHit", DGUN_HIT),
        template("DgunEnd", DGUN_END),
    ]}
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(model, f, indent=2)
        f.write("\n")
    print("wrote", os.path.normpath(OUT), "templates:", [c["Name"] for c in model["Children"]])


if __name__ == "__main__":
    main()
