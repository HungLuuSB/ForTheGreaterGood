"""Leg kit for the S-181 walking bots' meshes: the Commander walker legs
(rig.md 10, M-31) without the hip yokes, at the same hip, knee and ankle
points as the blockouts' Blockouts/Bots.luau, so the client's Bot stride
(the Commander's, scaled per bot) moves both alike. Per side a
`thigh{L,R}` jointed to `base` at the hip, a `shin{L,R}` at the knee, a
`foot{L,R}` at the ankle; tools/animate.py gives them `swing` X (BOT).

    import bots
    pieces = [...] + bots.legs(hip_y=2.6, hip_x=0.7, thick=0.55, faction="order")
"""

import unit
from mech import drum, piston, tseg

X = (1, 0, 0)


def points(hip_y, hip_x, thick, sx):
    """The blockout's hip, knee and ankle for side sx (-1 left, 1 right)."""
    x = sx * hip_x
    return (x, hip_y, 0.0), (x, hip_y * 0.52, -thick * 0.45), (x, max(0.45, thick * 0.7), 0.1)


def legs(hip_y, hip_x, thick, faction, team=True, foot_scale=1.0):
    """Six PieceSpecs (thighL, shinL, footL, thighR, shinR, footR). Order
    legs are armored and clean (a front plate, a team stripe, lit edges);
    Chaos legs are bare struts with a piston and claw toes (M-14)."""
    t = thick
    specs = []
    for sx in (-1, 1):
        n = "L" if sx < 0 else "R"
        hip, knee, ankle = points(hip_y, hip_x, t, sx)
        x = hip[0]

        def thigh(p, hip=hip, knee=knee, x=x, sx=sx):
            drum(p, hip, t * 0.55, t * 1.15, "steel", "trim", sides=12)
            if faction == "order":
                tseg(p, hip, knee, t, t * 1.1, t * 0.9, t * 1.0, "paint", pad=0.06, bevel=0.06)
                tseg(p, hip, knee, t * 1.15, t * 0.3, t, t * 0.26, "team" if team else "trim",
                     off0=t * 0.5, off1=t * 0.48, pad=-0.08, bevel=0.03)
                p.box((x + sx * t * 0.52, (hip[1] + knee[1]) / 2, (hip[2] + knee[2]) / 2), (0.03, (hip[1] - knee[1]) * 0.6, 0.08), "light")
            else:
                tseg(p, hip, knee, t * 0.7, t * 0.8, t * 0.6, t * 0.7, "trim", pad=0.06, bevel=0.04)
                tseg(p, hip, knee, t * 0.95, t * 0.25, t * 0.85, t * 0.22, "paint", off0=t * 0.42, off1=t * 0.4, pad=-0.1, bevel=0.03)
                piston(p, (x + sx * t * 0.45, hip[1] - 0.1, 0.15), (x + sx * t * 0.45, knee[1] + 0.2, knee[2] + 0.1), r=t * 0.11)
            drum(p, knee, t * 0.5, t * 1.05, "steel", "trim", sides=12)

        def shin(p, knee=knee, ankle=ankle, x=x, sx=sx):
            if faction == "order":
                tseg(p, knee, ankle, t * 0.9, t * 1.0, t * 0.8, t * 0.9, "paint", pad=0.04, bevel=0.06)
                tseg(p, knee, ankle, t * 1.05, t * 0.28, t * 0.9, t * 0.24, "trim", off0=t * 0.48, off1=t * 0.42, pad=-0.06, bevel=0.03)
            else:
                tseg(p, knee, ankle, t * 0.65, t * 0.75, t * 0.55, t * 0.65, "paint", pad=0.04, bevel=0.04)
                piston(p, (x, knee[1] - 0.1, knee[2] + t * 0.45), (x, ankle[1] + 0.15, ankle[2] + t * 0.35), r=t * 0.1, sleeve="steel")
                p.box((x, knee[1] - 0.3, knee[2] - t * 0.42), (t * 0.5, 0.12, 0.04), "light")
            drum(p, ankle, t * 0.38, t * 0.95, "steel", "trim", sides=10)

        def foot(p, ankle=ankle, x=x):
            f = foot_scale
            w, ln = t * 1.25 * f, t * 2.4 * f
            z0 = 0.1 - 0.3 * t
            p.box((x, 0.06, z0), (w, 0.12, ln), "dark")
            if faction == "order":
                p.prism_x([(z0 - ln / 2, 0.12), (z0 + ln / 2, 0.12), (z0 + ln / 2, 0.36), (z0 + ln * 0.15, 0.42),
                           (z0 - ln * 0.3, 0.38), (z0 - ln / 2, 0.24)], x - w / 2, x + w / 2, "paint", bevel=0.06)
                p.box((x, 0.3, z0 - ln / 2 + 0.02), (w * 0.7, 0.08, 0.03), "light")
            else:
                p.box((x, 0.3, z0 + ln * 0.15), (w * 0.8, 0.36, ln * 0.6), "paint", bevel=0.04)
                for k in (-1, 0, 1):  # claw toes
                    p.prism_x([(z0 - ln / 2 - 0.15, 0.04), (z0 - ln * 0.1, 0.04), (z0 - ln * 0.1, 0.34)],
                              x + k * w * 0.32 - w * 0.12, x + k * w * 0.32 + w * 0.12, "steel", bevel=0.02)

        none = lambda p: None  # noqa: E731
        specs += [unit.PieceSpec(f"thigh{n}", "base", hip, thigh, none),
                  unit.PieceSpec(f"shin{n}", f"thigh{n}", knee, shin, none),
                  unit.PieceSpec(f"foot{n}", f"shin{n}", ankle, foot, none)]
    return specs


def previews(height):
    """Preview cameras framed on a bot `height` studs tall (the default
    framing sizes on `base`, which for a bot is only the pelvis)."""
    h = height
    return [("35", (-2.2 * h, 1.8 * h, -2.6 * h), (0, 0.5 * h, 0), 50),
            ("side", (3.0 * h, 0.6 * h, 0), (0, 0.5 * h, 0), 50),
            ("80", (0, 3.6 * h, 0.7 * h), (0, 0.45 * h, 0), 50),
            ("close", (-1.1 * h, 1.0 * h, -1.3 * h), (0, 0.72 * h, -0.1 * h), 35)]
