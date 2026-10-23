"""Animated pieces (M-27, docs/contracts/rig.md "Animated pieces"): how the
client may move each piece that should move, by unit ID. Pieces that are
whole PieceSpecs are listed here; sub-pieces split out of a piece with
`lib.Piece.sub` carry their own entry from the build script. tools/unit.py
merges both into rig.json `anim`; `python assets/models/tools/animate.py
--patch` writes this table into existing exports without a rebuild.

An entry is {"motion", "axis", "range"?}, axis in model space (forward = -Z,
a positive rotation about it is the opening / forward direction):
  spin    continuous rotation about axis (rotors, wheels, fans)
  turn    slow continuous or sweeping yaw about axis (radar dishes, arrays)
  scroll  a track set: the band and road wheels move together (bob, judder;
          the band's UVs run along its length)
  slide   translation along axis, `range` studs (cranes, trolleys, gantries)
  open    rotation about axis up to `range` degrees (hatches, covers, doors)
  lower   translation along axis, `range` studs (dipping sonar)
  pulse   scale / emissive pulse about the pivot (cores)
  swing   an oscillating hinge about axis, driven by the walk cycle (walker joints)
"""

import json
import os
import sys

Y, X, Z = (0, 1, 0), (1, 0, 0), (0, 0, 1)


def a(motion, axis, rng=None):
    e = {"motion": motion, "axis": list(axis)}
    if rng is not None:
        e["range"] = rng
    return e


HELI = {"rotor": a("spin", Y)}
# the Commander mechs (M-31, rig.md 10): torso and head turn, every limb swings
WALKER = {"torso": a("turn", Y), "head": a("turn", Y), "armL": a("swing", X), "armR": a("swing", X),
          "forearmR": a("swing", X), **{f"{j}{s}": a("swing", X) for j in ("hip", "thigh", "shin", "foot") for s in "LR"}}
ANIM = {
    # helicopters' main rotors (tail rotors are sub-pieces)
    "ord_skywright": HELI, "chs_vulture": HELI, "ord_guardian": HELI, "chs_wasp": HELI,
    "ord_zenith": HELI, "chs_condor": HELI, "ord_tidewatch": HELI, "chs_leech": HELI,
    # windmills
    "ord_windmill": {"rotor": a("spin", Z)}, "chs_windmill": {"rotor": a("spin", Z)},
    # radar dishes and arrays
    "ord_oracle": {"dish": a("turn", Y)}, "chs_watcher": {"dish": a("turn", Y)},
    "ord_arbiter": {"dish": a("turn", Y)}, "chs_stalker": {"dish": a("turn", Y)},
    "ord_watchtower": {"radar": a("turn", Y)}, "chs_eye": {"radar": a("turn", Y)},
    "ord_citadel": {"radar": a("turn", Y)},
    # jammer arrays
    "ord_veil": {"array": a("turn", Y)}, "chs_shroud": {"array": a("turn", Y)},
    # shield generator cores
    "ord_phalanx": {"core": a("pulse", Y)}, "chs_carapace": {"core": a("pulse", Y)},
    # silo hatches, bomb bays
    "ord_reckoning": {"hatch": a("open", Z, 110), "hatch2": a("open", (0, 0, -1), 110)},
    "chs_ragnarok": {"hatch": a("open", X, 110)},
    "ord_absolution": {"bay": a("open", Z, 60)}, "chs_plague": {"bay": a("open", Z, 60)},
    # beam tower lids (the `retracted` pose closes them; Blockouts/Pending)
    "ord_sovereign": WALKER, "chs_warlord": WALKER,
    "ord_radiance": {"shellL": a("open", (0, 0, -1), 90), "shellR": a("open", Z, 90)},
    "chs_inferno": {"shellL": a("open", (0, 0, -1), 90), "shellR": a("open", Z, 90)},
}


def for_unit(unit_id):
    return ANIM.get(unit_id, {})


def patch():
    """Merges the table into every existing export/rig.json (no rebuild)."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for uid in sorted(ANIM):
        path = os.path.join(root, uid, "export", "rig.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            rig = json.load(f)
        anim = rig.setdefault("anim", {})
        anim.update({k: v for k, v in for_unit(uid).items() if k in rig["pieces"]})
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(rig, indent=2) + "\n")
        print(f"patched {uid}")


if __name__ == "__main__" and "--patch" in sys.argv:
    patch()
