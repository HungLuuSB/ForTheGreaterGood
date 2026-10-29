"""Particle templates for the client's Render/Vfx (C-47; F27, the user's
beta feedback 2026-10-26: "Shot does not look powerful enough ... Push the
limit"). Writes place/Vfx.model.json, which Rojo puts in ReplicatedStorage
as `Vfx` (default/serve/build project files), where Render/Vfx looks up a
template by name on every burst (Vfx.TEMPLATE_NAMES).

    python assets/fx/vfx/build_vfx.py

Explosions (the user, 2026-10-30: "make the explosion effect more appealing
to today's standards ... for unit death, structure, nuke", references in
assets/reference/unit_explosion; our own look, nothing copied). Authored at
scale 1 = a 7-stud explosion (the client scales sizes and speeds by the
burst's diameter / 7, capped at 6, counts by up to 2.5); played upright.
- `Death`: every unit's death (C-232). A Folder: `Blast` (pre-flash and
  rays, a soft glow halo, shock sphere, bubbly hot blobs, a fireball cooling
  into smoke, a ground shock ring, dust and fire rings, shrapnel, sparks,
  debris, secondary pops, flames on the wreck, embers, a short ground glow,
  two lights) and five debris `Arm`s: burning chunks flung out on tilted
  attachments, each leaving a line of smoke.
- `StructureDeath`: the same, heavier, plus a dust cloud rolling out low,
  three chain explosions at their own spots, fires left in the rubble, a
  smoke column and seven arms.
- `Impact`: shells, bombs, missile hits (the most frequent, kept cheap).
- `Nuke`: strategic warheads (scale 1 = a 150-stud blast): a blinding flash
  with spikes, a condensation shell, a ground shockwave to ~3x the blast, a
  long-burning fireball rising into a fire-lit stem and mushroom cap, dust
  rolled out, the crater glowing with burning spots, debris and embers.
Emitters with `GroundOnly` belong to a ground burst only. The lasting
ground mark is the client's blast-mark decal (assets/fx/scorch).

Missiles (the user: "They lack some key aspect (fire booster,...)"),
authored for the 1x missile (4.4 studs), facing the flight with -Z:
- `MissileExhaust` (Continuous, like `DgunBolt`): on the nozzle, a white-hot
  core, a long flame plume with a hotter inner cone, four shock diamonds
  (`Diamond1..4` attachments behind the nozzle), a wide glow, sparks and a
  thick rocket-smoke trail lit orange at the nozzle; a light.
- `Launch`: the booster lighting: a flash, a backblast of fire, sparks, a
  big launch-smoke cloud and billows round the launcher.

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
burst); per light: `LightSeconds`; per template: `Continuous`. Attributes are written
typed under Properties.Attributes (Rojo drops a top-level "Attributes").
Built-in Studio particle textures only.
"""

import json
import math
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
FACING, VEL_PARALLEL, VEL_PERP = 0, 2, 3  # ParticleOrientation (1 is FacingCameraWorldUp)


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
            rot_speed=(-60, 60), squash=None, zoffset=0.0, brightness=1.0, rate=0, locked=False, ground=False):
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
    if ground:
        attrs["GroundOnly"] = True  # a ground burst's only: the client skips it for a burst in the air
    return {"Name": name, "ClassName": "ParticleEmitter", "Properties": props, "Attributes": attrs}


def light(color, range_, brightness, seconds=None, on=False, name="Light"):
    """A PointLight: flashes and fades over `seconds`, or (`on`) stays lit while a continuous rig runs."""
    out = {"Name": name, "ClassName": "PointLight",
           "Properties": {"Color": {"Color3": [c / 255 for c in color]}, "Range": range_, "Brightness": brightness,
                          "Shadows": False, "Enabled": on}}
    if seconds is not None:
        out["Attributes"] = {"LightSeconds": seconds}
    return out


def attachment(name, children, at=(0, 0, 0), up=None):
    """An Attachment at `at` (studs from the carrier), its +Y turned to `up` if given."""
    rot = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    if up is not None:
        u = up
        ref = (0.0, 0.0, 1.0) if abs(u[2]) < 0.9 else (1.0, 0.0, 0.0)
        r = (u[1] * ref[2] - u[2] * ref[1], u[2] * ref[0] - u[0] * ref[2], u[0] * ref[1] - u[1] * ref[0])
        lr = math.sqrt(sum(c * c for c in r))
        r = tuple(c / lr for c in r)
        b = (r[1] * u[2] - r[2] * u[1], r[2] * u[0] - r[0] * u[2], r[0] * u[1] - r[1] * u[0])
        rot = [[r[0], u[0], b[0]], [r[1], u[1], b[1]], [r[2], u[2], b[2]]]
    return {"Name": name, "ClassName": "Attachment", "Children": children,
            "Properties": {"CFrame": {"CFrame": {"position": list(at), "orientation": rot}}}}


HOT = (255, 246, 214)
WHITE = (255, 252, 240)
YELLOW = (255, 214, 120)
ORANGE = (255, 140, 48)
RED = (196, 52, 18)
EMBER = (255, 120, 40)
SOOT = (34, 30, 28)
CHAR = (80, 30, 14)
DUST = (150, 130, 104)
DUST_FAR = (128, 118, 106)

# The explosions (the user, 2026-10-30: "make the explosion effect more appealing to today's
# standards ... for unit death, structure, nuke", with the references in
# assets/reference/unit_explosion). Layered as modern game explosions are:
# - a white pre-flash with a starburst of rays, a wide soft glow halo (it reads from the RTS
#   camera above), a pale shock sphere and a shock ring racing along the ground;
# - bright bubbly blobs at the heart, a fireball that cools through orange and red into smoke
#   as it climbs (the fire-to-smoke handoff), dark smoke billowing round it;
# - a dust ring kicked off the ground and a ring of fire;
# - shrapnel streaks, sparks, burning and dark debris in arcs, and debris "arms": burning
#   chunks flung out on tilted attachments, each leaving a line of dark smoke behind it;
# - small secondary pops, embers drifting up for seconds, a glowing scorch cooling to black;
# - two lights: a sharp flash, then the fire's glow.
# Emitters marked `GroundOnly` belong to a ground burst only (the client skips them in the air).
# Built-in Studio textures only; our own look, not copied from the references.


def blast_core(k=1.0):
    """The flash, glow, shock, fireball and smoke every explosion shares; `k` scales the counts."""
    n = lambda c: max(1, round(c * k))  # noqa: E731
    return [
        # the pre-flash: a white pop that is gone in a few frames
        emitter("PreFlash", TEX["core"], 1, (0.06, 0.08), (0, 0), ns((0, 1.0), (1, 10.0)),
                cs((0, WHITE), (1, HOT)), ns((0, 0), (1, 1)), light_emission=1, brightness=6, zoffset=4),
        # a starburst of rays at the flash
        emitter("Rays", TEX["square"], n(16), (0.1, 0.16), (60, 90), ns((0, 0.35), (1, 0.1)),
                cs((0, WHITE), (1, YELLOW)), ns((0, 0), (0.6, 0.3), (1, 1)),
                light_emission=1, orientation=VEL_PARALLEL, rotation=(0, 0), rot_speed=(0, 0),
                squash=ns((0, -6.0), (1, -3.0)), brightness=4, zoffset=3),
        # the white-hot flash at the heart
        emitter("Flash", TEX["core"], 2, (0.12, 0.18), (0, 0), ns((0, 2.0), (0.3, 4.5), (1, 5.0)),
                cs((0, HOT), (0.4, YELLOW), (1, ORANGE)), ns((0, 0), (0.5, 0.2), (1, 1)), light_emission=1, brightness=3, zoffset=3),
        # the glow halo: a wide soft bloom round the whole burst
        emitter("Halo", TEX["core"], 1, (0.4, 0.5), (0, 0), ns((0, 5.0), (0.3, 9.0), (1, 10.0)),
                cs((0, ORANGE), (0.5, (230, 100, 36)), (1, RED)), ns((0, 0.7), (0.5, 0.82), (1, 1)), light_emission=1, brightness=1),
        # the shockwave: a pale sphere snapping out
        emitter("AirShock", TEX["shock"], 1, (0.25, 0.32), (0, 0), ns((0, 1.0), (1, 14.0)),
                cs((0, (255, 236, 210)), (1, (230, 200, 176))), ns((0, 0.2), (1, 1)), light_emission=0.7, brightness=1.6, zoffset=2),
        # bright bubbly blobs boiling at the heart
        emitter("Blobs", TEX["core"], n(8), (0.25, 0.4), (0.5, 5), ns((0, 1.8, 0.4), (0.4, 2.6), (1, 0.6)),
                cs((0, WHITE), (0.35, YELLOW), (1, ORANGE)), ns((0, 0), (0.7, 0.2), (1, 1)),
                spread=(70, 70), light_emission=1, brightness=3, zoffset=2),
        # the white-hot core of the fireball
        emitter("FireCore", TEX["fire"], n(10), (0.25, 0.4), (0.5, 3), ns((0, 2.5, 0.5), (0.3, 4.5, 0.6), (1, 2.0)),
                cs((0, HOT), (0.35, YELLOW), (1, ORANGE)), ns((0, 0), (0.7, 0.2), (1, 1)),
                spread=(60, 60), accel=(0, 4, 0), drag=3, light_emission=1, rot_speed=(-200, 200), brightness=2.5, zoffset=2),
        # the rolling fireball, cooling from yellow through orange and red to soot
        emitter("Fireball", TEX["fire"], n(24), (0.7, 1.2), (1, 10), ns((0, 2.2, 0.5), (0.3, 4.0, 0.8), (1, 1.4)),
                cs((0, YELLOW), (0.25, ORANGE), (0.55, RED), (0.8, CHAR), (1, (40, 30, 26))), ns((0, 0), (0.6, 0.15), (1, 1)),
                spread=(80, 80), accel=(0, 6, 0), drag=3.5, light_emission=0.75, rot_speed=(-160, 160), brightness=1.8, zoffset=1),
        # the fire turning into smoke as it climbs: the plume starts glowing and goes dark
        emitter("Plume", TEX["smoke"], n(16), (1.8, 2.8), (4, 8), ns((0, 2.2, 0.4), (0.3, 4.5, 0.8), (1, 8.0)),
                cs((0, ORANGE), (0.08, (150, 64, 28)), (0.22, (78, 64, 54)), (1, (96, 92, 88))), ns((0, 0.15), (0.5, 0.4), (1, 1)),
                delay=0.1, spread=(35, 35), accel=(0, 7, 0), drag=1.4, light_emission=0.2, light_influence=0.8, rot_speed=(-40, 40)),
        # dark smoke billowing out wider round it
        emitter("Smoke", TEX["smoke"], n(12), (2.6, 3.8), (2, 5), ns((0, 3.0, 0.5), (0.4, 6.0, 0.9), (1, 9.0)),
                cs((0, (74, 68, 62)), (1, (110, 106, 102))), ns((0, 0.4), (0.4, 0.5), (1, 1)),
                delay=0.2, spread=(70, 70), accel=(0, 4, 0), drag=1.2, light_influence=1, rot_speed=(-30, 30)),
    ]


def blast_ground(k=1.0):
    """What a ground burst throws along the ground: a shock ring, a dust ring and a ring of fire."""
    n = lambda c: max(1, round(c * k))  # noqa: E731
    return [
        # the shockwave racing out along the ground (flat: faces its upward velocity)
        emitter("GroundShock", TEX["shock"], 1, (0.3, 0.38), (0.01, 0.01), ns((0, 2.0), (1, 17.0)),
                cs((0, (255, 240, 210)), (1, ORANGE)), ns((0, 0.15), (1, 1)),
                spread=(0, 0), orientation=VEL_PERP, light_emission=0.6, rot_speed=(0, 0), ground=True),
        # dust kicked out in a ring, lit by the sun, not glowing
        emitter("DustRing", TEX["puff"], n(28), (1.0, 1.6), (12, 18), ns((0, 1.2, 0.3), (0.3, 3.5, 0.6), (1, 5.0)),
                cs((0, DUST), (1, DUST_FAR)), ns((0, 0.3), (0.5, 0.55), (1, 1)),
                direction=FRONT, spread=(0, 180), accel=(0, 1, 0), drag=3.5, light_influence=1, rot_speed=(-40, 40), ground=True),
        # the ring of fire racing out along the ground
        emitter("FireRing", TEX["fire"], n(32), (0.4, 0.6), (16, 20), ns((0, 1.0), (0.3, 2.2, 0.4), (1, 0.6)),
                cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.1), (0.7, 0.3), (1, 1)),
                direction=FRONT, spread=(0, 180), accel=(0, 2, 0), drag=3.5, light_emission=1, brightness=1.8, ground=True),
    ]


def blast_throw(k=1.0, chunk=1.0):
    """What a blast throws out: shrapnel, sparks, burning and dark debris (`chunk` sizes the debris)."""
    n = lambda c: max(1, round(c * k))  # noqa: E731
    return [
        # shrapnel: thin white-hot streaks, the fastest thing in it
        emitter("Shrapnel", TEX["square"], n(20), (0.18, 0.3), (40, 60), ns((0, 0.1), (1, 0.04)),
                cs((0, WHITE), (1, YELLOW)), ns((0, 0), (0.7, 0.2), (1, 1)),
                spread=(85, 85), drag=1.5, light_emission=1, orientation=VEL_PARALLEL,
                rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -4.0), (1, -2.0)), brightness=3),
        # long sparks streaking up and out, falling back
        emitter("Sparks", TEX["square"], n(34), (0.45, 0.9), (18, 32), ns((0, 0.16), (1, 0.05)),
                cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0), (0.8, 0.2), (1, 1)),
                spread=(55, 55), accel=(0, -32, 0), drag=1.0, light_emission=1, orientation=VEL_PARALLEL,
                rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.5), (1, -1.2)), brightness=2),
        # burning pieces arcing out
        emitter("DebrisFire", TEX["fire"], n(8), (0.6, 1.0), (10, 18), ns((0, 0.9 * chunk), (1, 0.3 * chunk)),
                cs((0, YELLOW), (0.5, ORANGE), (1, RED)), ns((0, 0), (0.7, 0.2), (1, 1)),
                spread=(60, 60), accel=(0, -30, 0), drag=0.5, light_emission=1, rot_speed=(-300, 300), brightness=2),
        # dark debris thrown in arcs
        emitter("Debris", TEX["square"], n(16), (0.9, 1.4), (10, 20), ns((0, 0.2 * chunk, 0.06 * chunk), (1, 0.14 * chunk)),
                cs((0, (60, 54, 50)), (1, (30, 28, 26))), ns((0, 0), (0.85, 0), (1, 1)),
                spread=(70, 70), accel=(0, -45, 0), drag=0.6, light_influence=1, rot_speed=(-360, 360)),
    ]


def blast_after(k=1.0, scorch=6.5, scorch_life=(0.9, 1.3)):
    """What follows: secondary pops, embers drifting up and the scorch left on the ground."""
    n = lambda c: max(1, round(c * k))  # noqa: E731
    return [
        # small secondary pops as fuel and ammunition cook off
        emitter("Pops", TEX["fire"], n(6), (0.25, 0.4), (5, 10), ns((0, 1.2), (0.3, 2.6), (1, 0.5)),
                cs((0, HOT), (0.3, YELLOW), (1, ORANGE)), ns((0, 0), (0.6, 0.2), (1, 1)),
                delay=0.22, spread=(80, 80), drag=4, light_emission=1, rot_speed=(-200, 200), brightness=2.2),
        emitter("Pops2", TEX["fire"], n(4), (0.25, 0.4), (4, 8), ns((0, 1.0), (0.3, 2.2), (1, 0.4)),
                cs((0, HOT), (0.3, YELLOW), (1, ORANGE)), ns((0, 0), (0.6, 0.2), (1, 1)),
                delay=0.42, spread=(80, 80), drag=4, light_emission=1, rot_speed=(-200, 200), brightness=2.2),
        # flames left licking at the wreck for a couple of seconds
        emitter("Burning", TEX["fire"], n(8), (1.2, 2.0), (3, 10), ns((0, 0.8, 0.2), (0.3, 1.6, 0.3), (1, 0.3)),
                cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.15), (0.6, 0.3), (1, 1)),
                delay=0.5, direction=FRONT, spread=(15, 180), accel=(0, 4, 0), drag=2, light_emission=0.7, rot_speed=(-60, 60), brightness=1.1),
        # glowing embers drifting up afterwards
        emitter("Embers", TEX["sparkle"], n(14), (1.6, 2.6), (5, 14), ns((0, 0.25), (1, 0.06)),
                cs((0, YELLOW), (1, EMBER)), ns((0, 0.1), (0.5, 0.4), (1, 1)),
                delay=0.15, spread=(75, 75), accel=(0, 4, 0), drag=1.8, light_emission=1, brightness=1.5),
        # the ground glowing where the blast hit, for a second (flat: faces its upward velocity); the
        # lasting mark is the client's blast-mark decal (assets/fx/scorch)
        emitter("GroundGlow", TEX["core"], 1, scorch_life, (0.01, 0.01), ns((0, scorch * 0.8), (0.2, scorch), (1, scorch * 1.05)),
                cs((0, YELLOW), (0.3, ORANGE), (1, RED)), ns((0, 0.25), (0.5, 0.6), (1, 1)),
                spread=(0, 0), orientation=VEL_PERP, light_emission=1, brightness=1.5, rot_speed=(0, 0), zoffset=-1, ground=True),
    ]


def blast_lights(flash=(26, 8, 0.12), glow=(18, 5, 0.8)):
    return [light(HOT, flash[0], flash[1], seconds=flash[2], name="Flash"),
            light((255, 150, 70), glow[0], glow[1], seconds=glow[2], name="Glow")]


def arm(i, tilt, yaw, reach=1.0, smoke=10):
    """A debris arm: a burning chunk flung out along a tilted attachment's up (+Y), leaving a
    line of dark smoke behind it (puffs at a spread of speeds string out along one line)."""
    a, b = math.radians(tilt), math.radians(yaw)
    up = (math.sin(a) * math.cos(b), math.cos(a), math.sin(a) * math.sin(b))
    return attachment(f"Arm{i}", [
        emitter("ArmFire", TEX["fire"], 2, (0.6, 0.8), (22 * reach, 24 * reach), ns((0, 0.8), (0.5, 0.6), (1, 0.2)),
                cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.1), (0.7, 0.3), (1, 1)),
                spread=(2, 2), accel=(0, -14, 0), drag=0.8, light_emission=1, rot_speed=(-300, 300), brightness=1.6, zoffset=1),
        emitter("ArmSmoke", TEX["smoke"], smoke, (1.6, 2.4), (3 * reach, 22 * reach), ns((0, 0.8, 0.2), (0.3, 1.8), (1, 2.8)),
                cs((0, (110, 70, 44)), (0.15, (70, 64, 58)), (1, (110, 106, 102))), ns((0, 0.25), (0.5, 0.5), (1, 1)),
                spread=(3, 3), accel=(0, -8, 0), drag=0.8, light_influence=1, rot_speed=(-30, 30)),
    ], up=up)


def arms(spec):
    return [arm(i + 1, t, y, r) for i, (t, y, r) in enumerate(spec)]


# `Death`: every unit's death (scale 1 = a 7-stud explosion; the client scales sizes and speeds by
# the burst's diameter / 7, up to 6, and counts by up to 2.5). A Folder: the blast at the carrier,
# five debris arms round it.
DEATH = blast_core() + blast_ground() + blast_throw() + blast_after() + blast_lights()
DEATH_ARMS = arms([(48, 10, 1.0), (60, 85, 0.85), (40, 160, 1.1), (55, 230, 0.9), (65, 300, 1.0)])

# `StructureDeath`: a building coming down. The death's blast, more of it, plus what a building
# does: a heavy dust cloud rolling out low as it collapses, big slabs, a chain of secondary
# explosions over a second and a half, fires left burning in the rubble, a taller smoke column,
# and seven debris arms.
STRUCTURE_DEATH = blast_core(1.3) + blast_ground(1.3) + blast_throw(1.2, chunk=2.2) + blast_after(1.5, scorch=8.0, scorch_life=(1.2, 1.6)) + [
    # the collapse: a thick dust cloud rolling out low and slow
    emitter("Collapse", TEX["puff"], 24, (2.5, 4.0), (6, 12), ns((0, 3.0, 0.6), (0.3, 6.0, 1.0), (1, 9.0)),
            cs((0, (140, 124, 104)), (1, (120, 114, 106))), ns((0, 0.15), (0.5, 0.35), (1, 1)),
            delay=0.15, direction=FRONT, spread=(25, 180), accel=(0, 1.5, 0), drag=1.6, light_influence=1, rot_speed=(-20, 20), ground=True),
    # fires left burning in the rubble
    emitter("Fires", TEX["fire"], 14, (2.0, 3.2), (4, 14), ns((0, 1.0, 0.3), (0.3, 2.2, 0.5), (1, 0.4)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.15), (0.6, 0.3), (1, 1)),
            delay=0.6, direction=FRONT, spread=(15, 180), accel=(0, 3, 0), drag=2, light_emission=0.7, rot_speed=(-60, 60), brightness=1.1),
    # the smoke column climbing above it
    emitter("Column", TEX["smoke"], 14, (4.0, 6.0), (6, 10), ns((0, 3.0, 0.6), (0.4, 6.5, 1.0), (1, 11.0)),
            cs((0, (60, 52, 46)), (0.4, (52, 50, 48)), (1, (90, 88, 86))), ns((0, 0.25), (0.5, 0.45), (1, 1)),
            delay=0.4, spread=(15, 15), accel=(0, 4, 0), drag=0.8, light_influence=1, rot_speed=(-20, 20)),
    light((255, 140, 60), 20, 4, seconds=1.8, name="Burn"),
]
# the chain of secondary explosions as the building's stores go up, each at its own spot on it
STRUCTURE_CHAIN = [
    attachment("Chain1", [
        emitter("Blast", TEX["fire"], 8, (0.35, 0.6), (0.5, 6), ns((0, 2.0), (0.3, 4.0), (1, 1.0)),
                cs((0, HOT), (0.25, YELLOW), (0.6, ORANGE), (0.85, CHAR), (1, (50, 34, 28))), ns((0, 0), (0.6, 0.2), (1, 1)),
                delay=0.45, spread=(70, 70), drag=3, light_emission=1, rot_speed=(-180, 180), brightness=2.2, zoffset=1),
    ], (4, 1, 3)),
    attachment("Chain2", [
        emitter("Blast", TEX["fire"], 8, (0.35, 0.6), (0.5, 6), ns((0, 1.8), (0.3, 3.6), (1, 0.9)),
                cs((0, HOT), (0.25, YELLOW), (0.6, ORANGE), (0.85, CHAR), (1, (50, 34, 28))), ns((0, 0), (0.6, 0.2), (1, 1)),
                delay=0.85, spread=(70, 70), drag=3, light_emission=1, rot_speed=(-180, 180), brightness=2.2, zoffset=1),
    ], (-5, 1, -2)),
    attachment("Chain3", [
        emitter("Blast", TEX["fire"], 10, (0.4, 0.7), (0.5, 6), ns((0, 2.4), (0.3, 4.6), (1, 1.2)),
                cs((0, HOT), (0.25, YELLOW), (0.6, ORANGE), (0.85, CHAR), (1, (50, 34, 28))), ns((0, 0), (0.6, 0.2), (1, 1)),
                delay=1.3, spread=(60, 60), drag=3, light_emission=1, rot_speed=(-180, 180), brightness=2.4, zoffset=1),
    ], (1, 1, -5)),
]
STRUCTURE_ARMS = arms([(45, 0, 1.2), (60, 50, 1.0), (38, 105, 1.3), (55, 160, 1.1),
                       (66, 210, 0.9), (42, 260, 1.2), (58, 320, 1.0)])

# `Impact`: a shell or bomb landing, the blast a unit throws when it dies, a missile hitting. The
# most frequent explosion of all, so it stays cheap (about 50 particles, one light) and faces the
# shot (the client turns its -Z along the shell's flight).
IMPACT = [
    emitter("Flash", TEX["core"], 2, (0.1, 0.14), (0, 0), ns((0, 2.0), (0.4, 6.0), (1, 6.5)),
            cs((0, WHITE), (0.4, YELLOW), (1, ORANGE)), ns((0, 0), (0.5, 0.2), (1, 1)), light_emission=1, brightness=3, zoffset=2),
    emitter("Rays", TEX["square"], 8, (0.08, 0.12), (50, 70), ns((0, 0.25), (1, 0.08)),
            cs((0, WHITE), (1, YELLOW)), ns((0, 0), (0.6, 0.3), (1, 1)),
            light_emission=1, orientation=VEL_PARALLEL, rotation=(0, 0), rot_speed=(0, 0),
            squash=ns((0, -5.0), (1, -2.5)), brightness=3.5, zoffset=2),
    emitter("Halo", TEX["core"], 1, (0.3, 0.36), (0, 0), ns((0, 6.0), (0.3, 10.0), (1, 11.0)),
            cs((0, YELLOW), (1, ORANGE)), ns((0, 0.5), (0.5, 0.75), (1, 1)), light_emission=1, brightness=1.4),
    emitter("AirShock", TEX["shock"], 1, (0.16, 0.2), (0, 0), ns((0, 1.0), (1, 9.0)),
            cs((0, (255, 236, 210)), (1, (230, 200, 176))), ns((0, 0.3), (1, 1)), light_emission=0.7, brightness=1.4, zoffset=1),
    emitter("Fireball", TEX["fire"], 10, (0.3, 0.55), (3, 8), ns((0, 2.0, 0.4), (0.3, 3.6, 0.6), (1, 1.0)),
            cs((0, YELLOW), (0.3, ORANGE), (0.65, RED), (1, (50, 34, 28))), ns((0, 0), (0.6, 0.2), (1, 1)),
            spread=(80, 80), accel=(0, 4, 0), drag=4, light_emission=0.8, rot_speed=(-180, 180), brightness=1.8),
    emitter("Sparks", TEX["square"], 12, (0.3, 0.6), (16, 30), ns((0, 0.13), (1, 0.04)),
            cs((0, HOT), (0.4, YELLOW), (1, ORANGE)), ns((0, 0), (0.8, 0.2), (1, 1)),
            spread=(60, 60), accel=(0, -30, 0), drag=1.2, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.4), (1, -1.0)), brightness=2),
    # dirt thrown up from the crater
    emitter("Dirt", TEX["puff"], 6, (0.8, 1.2), (6, 12), ns((0, 1.0, 0.2), (0.4, 2.6), (1, 3.4)),
            cs((0, (110, 94, 76)), (1, DUST_FAR)), ns((0, 0.15), (0.6, 0.4), (1, 1)),
            spread=(25, 25), accel=(0, -18, 0), drag=1.5, light_influence=1, rot_speed=(-60, 60), ground=True),
    emitter("Smoke", TEX["smoke"], 4, (1.6, 2.4), (1.5, 4), ns((0, 2.0, 0.4), (1, 5.5)),
            cs((0, (70, 64, 58)), (1, (120, 118, 114))), ns((0, 0.35), (0.5, 0.55), (1, 1)),
            delay=0.08, spread=(50, 50), accel=(0, 3, 0), drag=1.4, light_influence=1, rot_speed=(-30, 30)),
    light(ORANGE, 12, 4, seconds=0.18),
]

# `Nuke`: a strategic warhead (scale 1 = a 150-stud blast; the client draws it at aoe / 150, and
# the Commander's and fusion reactors' huge death blasts at their own radius). A blinding flash
# with spikes of light, a wide glow, a condensation shell, a shockwave sweeping the ground out to
# ~3x the blast, a fireball rising into a burning stem and a mushroom cap whose underside glows
# as it climbs, dust rolled out along the ground, the crater left glowing with burning spots,
# debris streaks, embers drifting for seconds and a wide scorch. Two lights (Range caps at 60 in
# Roblox; the client widens it by sqrt(scale)).
NUKE = [
    emitter("Flash", TEX["core"], 3, (0.35, 0.5), (0, 0), ns((0, 60.0), (1, 140.0)),
            cs((0, WHITE), (1, HOT)), ns((0, 0), (1, 1)), light_emission=1, brightness=8, zoffset=4),
    # spikes of light thrown out at the flash, mostly along the ground
    emitter("Spikes", TEX["square"], 24, (0.18, 0.28), (300, 500), ns((0, 5.0), (1, 1.5)),
            cs((0, WHITE), (1, YELLOW)), ns((0, 0), (0.6, 0.3), (1, 1)),
            direction=FRONT, spread=(20, 180), light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -8.0), (1, -4.0)), brightness=4, zoffset=3),
    emitter("Glare", TEX["core"], 2, (1.0, 1.4), (0, 0), ns((0, 80.0), (1, 120.0)),
            cs((0, HOT), (0.4, YELLOW), (1, ORANGE)), ns((0, 0.1), (0.5, 0.4), (1, 1)), light_emission=1, brightness=4, zoffset=3),
    emitter("Halo", TEX["core"], 1, (1.6, 2.0), (0, 0), ns((0, 160.0), (0.3, 300.0), (1, 320.0)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0.5), (0.6, 0.75), (1, 1)), light_emission=1, brightness=1.5),
    # the condensation shell: a white sphere that flashes out and thins away
    emitter("Shell", TEX["smoke"], 6, (1.0, 1.4), (5, 15), ns((0, 80.0), (1, 220.0)),
            cs((0, (250, 250, 250)), (1, (230, 232, 236))), ns((0, 0.55), (1, 1)), delay=0.15, light_influence=0.6, rot_speed=(-10, 10)),
    emitter("AirShock", TEX["shock"], 2, (0.6, 0.8), (0, 0), ns((0, 40.0), (1, 400.0)),
            cs((0, (240, 246, 255)), (1, (220, 230, 245))), ns((0, 0.3), (1, 1)), light_emission=0.6, brightness=1.5, zoffset=2),
    # the shockwave sweeping out along the ground
    emitter("GroundShock", TEX["shock"], 2, (1.6, 1.8), (0.01, 0.01), ns((0, 50.0), (1, 450.0)),
            cs((0, (255, 230, 190)), (1, (200, 180, 160))), ns((0, 0.1), (1, 1)),
            spread=(0, 0), orientation=VEL_PERP, light_emission=0.5, rot_speed=(0, 0), ground=True),
    emitter("Fireball", TEX["fire"], 60, (2.8, 4.2), (10, 50), ns((0, 30.0, 8.0), (0.3, 65.0, 10.0), (1, 60.0)),
            cs((0, WHITE), (0.12, YELLOW), (0.35, ORANGE), (0.7, RED), (1, (90, 35, 18))), ns((0, 0), (0.6, 0.2), (1, 1)),
            accel=(0, 10, 0), drag=3, light_emission=0.9, rot_speed=(-60, 60), brightness=2.5, zoffset=2),
    # the stem: a burning core early, then smoke
    emitter("StemFire", TEX["fire"], 30, (3.0, 4.2), (40, 90), ns((0, 18.0), (0.4, 30.0), (1, 10.0)),
            cs((0, YELLOW), (0.4, ORANGE), (1, RED)), ns((0, 0), (0.6, 0.3), (1, 1)),
            direction=TOP, spread=(6, 6), drag=0.8, light_emission=1, rot_speed=(-30, 30), brightness=2, zoffset=1),
    emitter("Stem", TEX["smoke"], 36, (6.0, 8.0), (40, 85), ns((0, 22.0, 4.0), (1, 48.0)),
            cs((0, (255, 140, 60)), (0.1, (190, 90, 45)), (0.3, (96, 72, 60)), (1, (120, 112, 106))), ns((0, 0.15), (0.7, 0.45), (1, 1)),
            direction=TOP, spread=(8, 8), accel=(0, 4, 0), drag=0.7, light_emission=0.25, light_influence=0.8, rot_speed=(-15, 15)),
    # the mushroom cap, its underside still burning as it climbs
    emitter("Cap", TEX["smoke"], 44, (8.0, 10.0), (110, 160), ns((0, 45.0, 8.0), (1, 120.0)),
            cs((0, (255, 170, 90)), (0.15, (220, 110, 50)), (0.35, (120, 82, 64)), (1, (132, 122, 114))), ns((0, 0.05), (0.6, 0.3), (1, 1)),
            direction=TOP, spread=(28, 28), accel=(0, 2, 0), drag=1.3, light_emission=0.3, light_influence=0.8, rot_speed=(-10, 10)),
    emitter("CapGlow", TEX["fire"], 40, (4.0, 6.0), (110, 150), ns((0, 40.0), (0.4, 70.0), (1, 30.0)),
            cs((0, YELLOW), (0.3, ORANGE), (0.7, RED), (1, (90, 35, 18))), ns((0, 0), (0.6, 0.3), (1, 1)),
            delay=0.3, direction=TOP, spread=(22, 22), drag=1.3, light_emission=0.8, rot_speed=(-20, 20), brightness=2.2),
    # dust rolled out along the ground
    emitter("Dust", TEX["puff"], 60, (4.0, 6.0), (120, 200), ns((0, 25.0, 5.0), (1, 60.0)),
            cs((0, DUST), (1, (175, 168, 158))), ns((0, 0.25), (0.6, 0.5), (1, 1)),
            direction=FRONT, spread=(4, 180), drag=2, light_influence=1, rot_speed=(-15, 15), ground=True),
    # the crater left glowing: burning spots scattered over it for seconds
    emitter("CraterFires", TEX["fire"], 40, (4.0, 7.0), (30, 120), ns((0, 6.0), (0.3, 5.0), (1, 1.5)),
            cs((0, YELLOW), (0.3, ORANGE), (1, RED)), ns((0, 0.1), (0.7, 0.3), (1, 1)),
            delay=0.5, direction=FRONT, spread=(0, 180), drag=3, light_emission=1, rot_speed=(-40, 40), brightness=2, ground=True),
    emitter("Debris", TEX["square"], 50, (1.5, 3.0), (80, 180), ns((0, 1.2), (1, 0.3)),
            cs((0, YELLOW), (0.5, ORANGE), (1, RED)), ns((0, 0), (0.8, 0.2), (1, 1)),
            spread=(70, 70), accel=(0, -60, 0), drag=1, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -3.0), (1, -1.5)), brightness=2),
    emitter("Embers", TEX["sparkle"], 60, (4.0, 7.0), (20, 60), ns((0, 3.0), (1, 1.0)),
            cs((0, YELLOW), (1, EMBER)), ns((0, 0), (0.7, 0.3), (1, 1)),
            delay=0.4, spread=(80, 80), accel=(0, 6, 0), drag=1, light_emission=1, brightness=2),
    emitter("GroundGlow", TEX["core"], 2, (5.0, 7.0), (0.01, 0.01), ns((0, 160.0), (0.1, 220.0), (1, 230.0)),
            cs((0, YELLOW), (0.15, ORANGE), (0.5, RED), (1, (80, 24, 10))), ns((0, 0.1), (0.5, 0.5), (1, 1)),
            spread=(0, 0), orientation=VEL_PERP, light_emission=0.3, rot_speed=(0, 0), zoffset=-1, ground=True),
    light(WHITE, 60, 14, seconds=0.5, name="Flash"),
    light((255, 160, 80), 60, 6, seconds=3.0, name="Glow"),
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


# Missiles (the user, 2026-10-30: "Missiles deserve enhancement too. They lack some key aspect
# (fire booster,...)"). Authored for the 1x missile (4.4 studs, IR SAMs; radar SAMs draw at 2.3x,
# strategic missiles at 4.5x: the client scales by its MISSILE_STYLE scale), facing the flight
# with -Z, so the exhaust streams out along +Z (NormalId Back).
BACK = 2  # NormalId: Back (+Z)
M_WHITE = (255, 250, 236)
M_YELLOW = (255, 220, 140)
M_ORANGE = (255, 150, 60)
M_SMOKE = (236, 234, 228)
M_SMOKE_FAR = (186, 184, 180)

# `MissileExhaust`: the booster, held on the missile's nozzle while it flies (Continuous, like
# DgunBolt: Rate emitters and a light that run until the client releases it). A white-hot core in
# the nozzle, a roaring flame plume with a hotter inner cone, a row of shock diamonds in the plume,
# a wide orange glow, sparks shed behind, and a thick rocket-smoke trail that leaves the nozzle lit
# orange and cools to white.
MISSILE_NOZZLE = [
    emitter("Core", TEX["core"], 0, (0.05, 0.08), (0, 0), ns((0, 1.0, 0.15), (1, 0.8)),
            cs((0, M_WHITE), (1, M_YELLOW)), ns((0, 0), (1, 0.6)),
            light_emission=1, brightness=4, zoffset=2, rate=50, locked=True),
    # the flame plume: streaks blown back out of the nozzle (held on the missile, so it stays a cone)
    emitter("Plume", TEX["fire"], 0, (0.13, 0.2), (22, 30), ns((0, 1.1, 0.15), (0.4, 0.95), (1, 0.2)),
            cs((0, M_WHITE), (0.3, M_YELLOW), (0.7, M_ORANGE), (1, (220, 80, 30))), ns((0, 0), (0.6, 0.2), (1, 1)),
            direction=BACK, spread=(6, 6), light_emission=1, orientation=VEL_PARALLEL, rotation=(0, 0), rot_speed=(0, 0),
            squash=ns((0, -1.6), (1, -0.8)), brightness=3, zoffset=1, rate=110, locked=True),
    emitter("InnerCone", TEX["core"], 0, (0.08, 0.11), (16, 22), ns((0, 0.6), (1, 0.15)),
            cs((0, M_WHITE), (1, M_YELLOW)), ns((0, 0), (1, 0.8)),
            direction=BACK, spread=(2, 2), light_emission=1, orientation=VEL_PARALLEL, rotation=(0, 0), rot_speed=(0, 0),
            squash=ns((0, -2.0), (1, -1.2)), brightness=4, zoffset=2, rate=60, locked=True),
    # the glow round the booster: it reads from the RTS camera when the missile itself doesn't
    emitter("Glow", TEX["core"], 0, (0.08, 0.12), (0, 0), ns((0, 4.5, 0.5), (1, 5.0)),
            cs((0, M_YELLOW), (1, M_ORANGE)), ns((0, 0.35), (1, 1)),
            light_emission=1, brightness=2, rate=24, locked=True),
    # sparks shed behind, left in world space
    emitter("Sparks", TEX["square"], 0, (0.2, 0.4), (4, 10), ns((0, 0.1), (1, 0.03)),
            cs((0, M_YELLOW), (1, M_ORANGE)), ns((0, 0), (0.8, 0.3), (1, 1)),
            direction=BACK, spread=(25, 25), accel=(0, -10, 0), drag=1.5, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -1.5), (1, -0.8)), brightness=2.5, rate=30),
    # the rocket-smoke trail: lit by the flame as it leaves the nozzle, then white, billowing out
    emitter("Smoke", TEX["smoke"], 0, (1.2, 1.8), (0.5, 2), ns((0, 0.8, 0.2), (0.25, 1.8, 0.3), (1, 4.0)),
            cs((0, M_ORANGE), (0.06, (230, 200, 170)), (0.2, M_SMOKE), (1, M_SMOKE_FAR)), ns((0, 0.2), (0.4, 0.5), (1, 1)),
            spread=(180, 180), drag=1.2, accel=(0, 1, 0), light_emission=0.15, light_influence=1, rot_speed=(-30, 30), rate=60),
    light(M_ORANGE, 12, 3, on=True),
]


def diamond(i, z, size):
    """A shock diamond: a bright knot standing in the plume `z` studs behind the nozzle."""
    return attachment(f"Diamond{i}", [
        emitter("Knot", TEX["core"], 0, (0.04, 0.06), (0, 0), ns((0, size, size * 0.25), (1, size * 0.8)),
                cs((0, M_WHITE), (1, M_YELLOW)), ns((0, 0.1), (1, 0.7)),
                light_emission=1, brightness=3.5, zoffset=3, rate=30, locked=True),
    ], (0, 0, z))


# (attachment positions aren't scaled by the client yet: Render/Vfx would scale them by the style)
MISSILE_DIAMONDS = [diamond(1, 0.9, 0.5), diamond(2, 1.7, 0.42), diamond(3, 2.5, 0.32), diamond(4, 3.2, 0.24)]

# `Launch`: the booster lighting on the launcher, facing the flight (-Z): a flash, a jet of
# fire blasted out behind, a burst of sparks, a big cloud of white launch smoke rolling out
# behind and round the launcher, and dust kicked along the ground (scale 1 = the IR SAM's).
LAUNCH = [
    emitter("Flash", TEX["core"], 2, (0.12, 0.18), (0, 0), ns((0, 2.5), (0.4, 5.0), (1, 5.5)),
            cs((0, M_WHITE), (0.5, M_YELLOW), (1, M_ORANGE)), ns((0, 0), (0.5, 0.2), (1, 1)),
            light_emission=1, brightness=3, zoffset=2),
    emitter("Backblast", TEX["fire"], 14, (0.2, 0.35), (18, 34), ns((0, 1.2, 0.3), (0.4, 2.4), (1, 0.6)),
            cs((0, M_WHITE), (0.3, M_YELLOW), (0.7, M_ORANGE), (1, (190, 70, 30))), ns((0, 0), (0.6, 0.2), (1, 1)),
            direction=BACK, spread=(18, 18), drag=3, light_emission=1, rot_speed=(-200, 200), brightness=2.5, zoffset=1),
    emitter("Sparks", TEX["square"], 14, (0.25, 0.5), (14, 28), ns((0, 0.12), (1, 0.04)),
            cs((0, M_WHITE), (0.4, M_YELLOW), (1, M_ORANGE)), ns((0, 0), (0.8, 0.2), (1, 1)),
            direction=BACK, spread=(40, 40), accel=(0, -24, 0), drag=1.2, light_emission=1, orientation=VEL_PARALLEL,
            rotation=(0, 0), rot_speed=(0, 0), squash=ns((0, -2.0), (1, -1.0)), brightness=2.5),
    emitter("Cloud", TEX["smoke"], 18, (2.5, 4.0), (6, 16), ns((0, 2.0, 0.5), (0.3, 5.0, 0.8), (1, 9.0)),
            cs((0, (255, 190, 120)), (0.05, M_SMOKE), (1, M_SMOKE_FAR)), ns((0, 0.15), (0.5, 0.45), (1, 1)),
            direction=BACK, spread=(70, 70), accel=(0, 1.5, 0), drag=2.5, light_emission=0.1, light_influence=1, rot_speed=(-25, 25)),
    emitter("Billow", TEX["puff"], 10, (1.6, 2.6), (2, 6), ns((0, 2.4, 0.5), (0.4, 5.0), (1, 6.5)),
            cs((0, M_SMOKE), (1, M_SMOKE_FAR)), ns((0, 0.3), (0.5, 0.55), (1, 1)),
            delay=0.05, spread=(180, 180), accel=(0, 2, 0), drag=2, light_influence=1, rot_speed=(-30, 30)),
    light(M_ORANGE, 16, 4, seconds=0.35),
]


def template(name, children, attributes=None):
    out = {"Name": name, "ClassName": "Attachment", "Children": children}
    if attributes:
        out["Attributes"] = attributes
    return out


def typed_attributes(node):
    """Moves each instance's "Attributes" into Properties.Attributes with explicit types: Rojo
    7.7 drops a top-level "Attributes" in a .model.json silently (found 2026-10-30, after the
    D-Gun templates had shipped without their EmitCount, EmitDelay and Continuous)."""
    attrs = node.pop("Attributes", None)
    if attrs:
        typed = {}
        for k, v in attrs.items():
            if isinstance(v, bool):
                typed[k] = {"Bool": v}
            elif isinstance(v, (int, float)):
                typed[k] = {"Float64": float(v)}
            else:
                typed[k] = {"String": str(v)}
        node.setdefault("Properties", {})["Attributes"] = {"Attributes": typed}
    for child in node.get("Children", []):
        typed_attributes(child)


def main():
    bolt = {"Name": "DgunBolt", "ClassName": "Folder", "Attributes": {"Continuous": True},
            "Children": [attachment("Bolt", DGUN_BOLT), attachment("Ground", DGUN_GROUND, (0, -5, 0))]}
    death = {"Name": "Death", "ClassName": "Folder", "Children": [attachment("Blast", DEATH)] + DEATH_ARMS}
    structure = {"Name": "StructureDeath", "ClassName": "Folder", "Children": [attachment("Blast", STRUCTURE_DEATH)] + STRUCTURE_CHAIN + STRUCTURE_ARMS}
    model = {"ClassName": "Folder", "Children": [
        death,
        structure,
        template("Impact", IMPACT),
        template("Nuke", NUKE),
        bolt,
        template("DgunMuzzle", DGUN_MUZZLE),
        template("DgunHit", DGUN_HIT),
        template("DgunEnd", DGUN_END),
        {"Name": "MissileExhaust", "ClassName": "Folder", "Attributes": {"Continuous": True},
         "Children": [attachment("Nozzle", MISSILE_NOZZLE)] + MISSILE_DIAMONDS},
        template("Launch", LAUNCH),
    ]}
    typed_attributes(model)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(model, f, indent=2)
        f.write("\n")
    print("wrote", os.path.normpath(OUT), "templates:", [c["Name"] for c in model["Children"]])


if __name__ == "__main__":
    main()
