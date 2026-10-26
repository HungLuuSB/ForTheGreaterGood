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
            rot_speed=(-60, 60), squash=None, zoffset=0.0, brightness=1.0):
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
        "Rate": 0,
        "Enabled": False,
    }
    if squash is not None:
        props["Squash"] = squash
    return {"Name": name, "ClassName": "ParticleEmitter", "Properties": props,
            "Attributes": {"EmitCount": count, "EmitDelay": delay}}


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


def template(name, children):
    return {"Name": name, "ClassName": "Attachment", "Children": children}


def main():
    model = {"ClassName": "Folder", "Children": [template("Death", DEATH)]}
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(model, f, indent=2)
        f.write("\n")
    print("wrote", os.path.normpath(OUT), "templates:", [c["Name"] for c in model["Children"]])


if __name__ == "__main__":
    main()
