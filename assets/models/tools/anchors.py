"""Construction anchors for the client's BAR-style nanoframe (M-25,
docs/contracts/rig.md section 8): Attachments on factories and constructors,
in final model space (after any `scale` in build.py), by unit ID.

- `buildpad` (factories): where the unit in production sits, centred on the
  pad; its forward (-Z) faces the exit. Every factory exits at model -Z (the
  sim spawns a finished unit one cell out along the factory's heading), so
  no rotation.
- `nano1`, `nano2`, ...: where nano-spray starts, at the factory's emitters /
  build lights, or at a constructor's emitter (under its `nano` piece).

tools/unit.py merges these into rig.json `attachments`; tools/anchors.py
--patch writes them into the existing export/rig.json files without a
rebuild. The blockouts carry the same Attachments in their own files.
"""

import json
import os
import sys

B, N = "base", "nano"

ANCHORS = {
    # factories
    "ord_vehplant": {"buildpad": (B, (0.0, 0.72, -3.0)),  # the build pad in the assembly bay (fp-4 redesign)
                     "nano1": (B, (-3.03, 6.4, -6.0)), "nano2": (B, (-3.03, 6.4, 0.0)),
                     "nano3": (B, (3.03, 6.4, -6.0)), "nano4": (B, (3.03, 6.4, 0.0))},
    "chs_vehplant": {"buildpad": (B, (3.0, 0.72, -2.0)),  # the pad under the gantry crane (fp-4 redesign)
                     "nano1": (B, (0.2, 6.15, -4.6)), "nano2": (B, (5.8, 6.15, 0.6)),
                     "nano3": ("trolley", (3.0, 7.32, -2.0))},  # the crane's hook block
    "ord_airfield": {"buildpad": (B, (-10.4, 0.72, -8.0)),  # the pad in front of the hangar
                     "nano1": (B, (-13.6, 5.3, -4.4)), "nano2": (B, (-7.2, 5.3, -4.4)), "nano3": (B, (-10.4, 8.0, -1.5))},
    "chs_airfield": {"buildpad": (B, (-10.8, 0.72, 6.8)),  # under the open hangar
                     "nano1": (B, (-14.4, 6.62, 6.8)), "nano2": (B, (-10.8, 6.62, 6.8)), "nano3": (B, (-7.2, 6.62, 6.8))},
    "ord_shipyard": {"buildpad": (B, (0.0, 0.0, -6.0)),  # in the slip, at the waterline, under the gantry
                     "nano1": (B, (-10.0, 11.0, -6.0)), "nano2": (B, (-4.0, 11.0, -6.0)),
                     "nano3": (B, (2.0, 11.0, -6.0)), "nano4": (B, (8.0, 11.0, -6.0)), "nano5": ("trolley", (4.0, 10.2, -6.0))},  # the trolley lamp slides with it
    "chs_shipyard": {"buildpad": (B, (0.0, 0.0, 1.0)),  # in the slip, under the tower crane's jib
                     "nano1": ("jib", (4.0, 12.0, 4.0)),  # the hook block's lamp, slews with the jib
                     "nano2": (B, (11.6, 4.15, 1.2))},  # the emitter arm on the right pier
    # T2 factories (footprint 6)
    "ord_advvehplant": {"buildpad": (B, (0.0, 0.9, -4.0)),  # the pad in the assembly bay
                        "nano1": (B, (-4.9, 7.4, -9.0)), "nano2": (B, (-4.9, 7.4, -4.0)), "nano3": (B, (-4.9, 7.4, 1.0)),
                        "nano4": (B, (4.9, 7.4, -9.0)), "nano5": (B, (4.9, 7.4, -4.0)), "nano6": (B, (4.9, 7.4, 1.0)),
                        "nano7": ("gantry", (3.0, 13.63, -6.0))},  # the gantry's build lamp slides with it
    "chs_advvehplant": {"buildpad": (B, (6.5, 0.76, -1.0)),  # the pad under the two bridge cranes
                        "nano1": ("trolley1", (-1.0, 9.72, -1.0)), "nano2": ("trolley2", (14.0, 9.72, -1.0)),  # hook blocks
                        "nano3": (B, (0.4, 6.69, -6.2)), "nano4": (B, (12.6, 6.69, -6.2))},  # booms off the front columns
    "ord_advairfield": {"buildpad": (B, (-3.0, 0.7, -11.0)),  # the apron pad in front of the assembly hangar
                        "nano1": (B, (-4.6, 5.5, -14.4)), "nano2": (B, (-4.6, 5.5, -7.6)), "nano3": (B, (-8.3, 8.4, -11.0))},
    "chs_advairfield": {"buildpad": (B, (-15.0, 0.66, -11.4)),  # under the open front hangar
                        "nano1": (B, (-20.4, 6.85, -11.4)), "nano2": (B, (-9.6, 6.85, -11.4)),  # the girder's end heads
                        "nano3": ("trolley", (-17.0, 6.15, -11.4))},  # the hoist trolley's head runs with it
    "ord_advshipyard": {"buildpad": (B, (0.0, 0.0, 1.0)),  # in the slip under the covered dock, at the waterline
                        "nano1": (B, (-5.3, 13.05, -4.0)), "nano2": (B, (-5.3, 13.05, 6.0)),  # lamps along the roof slot
                        "nano3": (B, (5.3, 13.05, -4.0)), "nano4": (B, (5.3, 13.05, 6.0)),
                        "nano5": ("gantry", (-7.0, 15.4, -17.4)), "nano6": ("gantry", (7.0, 15.4, -17.4))},  # travel with the gantry
    "chs_advshipyard": {"buildpad": (B, (0.0, 0.0, -1.0)),  # in the slip under the hammerhead's hook
                        "nano1": ("jib1", (-1.8, 13.73, 4.6)), "nano2": ("jib2", (1.8, 13.73, -7.0)),  # pier cranes' hook lamps
                        "nano3": ("jib", (8.0, 18.77, -1.0))},  # the hammerhead's hook lamp, slews with its jib
    # constructors: the emitter at the tip of the `nano` piece
    "ord_mason": {"nano1": (N, (0.0, 4.55, -1.45))},
    "chs_scrapper": {"nano1": (N, (1.182, 3.6, -1.814))},
    "ord_skywright": {"nano1": (N, (0.0, -0.55, -1.7))},
    "chs_vulture": {"nano1": (N, (0.0, -0.55, -1.7))},
    "ord_tidewright": {"nano1": (N, (0.0, 3.5, 0.1))},
    "chs_wrecker": {"nano1": (N, (0.0, 3.5, 0.1))},
    "ord_harbormaster": {"nano1": (N, (-0.55, 3.82, 1.1)), "nano2": (N, (0.55, 3.42, 5.7))},  # two arms (T2)
    "chs_reaver": {"nano1": (N, (-0.5, 3.72, 1.2)), "nano2": (N, (0.5, 3.32, 5.8))},
    "ord_architect": {"nano1": (N, (-0.8, 5.4, -1.4)), "nano2": (N, (0.8, 5.4, -1.4))},
    "chs_forgemaster": {"nano1": (N, (1.1, 5.7, -3.0)), "nano2": (N, (0.2, 3.9, 1.9))},
    "ord_sovereign": {"nano1": (N, (-3.35, 3.55, -1.64))},  # the heroic mech's emitter (M-32)
    "chs_warlord": {"nano1": (N, (-3.5, 3.25, -2.45))},
    "ord_zenith": {"nano1": (N, (0.0, -0.5, -2.1)), "nano2": (N, (0.0, -0.5, 1.6))},
    "chs_condor": {"nano1": (N, (0.0, 0.1, -1.9)), "nano2": (N, (0.0, 0.2, 2.1))},
    # S-181 bot factories: the pad under the gantry / in the pit, the emitter heads
    "ord_botlab": {"buildpad": (B, (0.0, 0.8, -6.5)),
                   "nano1": (B, (-4.5, 12.7, -6.5)), "nano2": (B, (4.5, 12.7, -6.5)), "nano3": (B, (0.0, 12.7, -6.5))},
    "chs_botlab": {"buildpad": (B, (0.0, 0.8, -2.0)),
                   "nano1": (B, (-3.5, 12.6, -2.0)), "nano2": (B, (3.5, 12.6, -2.0))},  # the hook blocks
    "ord_advbotlab": {"buildpad": (B, (0.0, 0.8, -8.0)),
                      "nano1": (B, (-9.0, 16.3, -8.0)), "nano2": (B, (9.0, 16.3, -8.0)),
                      "nano3": (B, (-3.0, 16.3, -8.0)), "nano4": (B, (3.0, 16.3, -8.0))},
    "chs_advbotlab": {"buildpad": (B, (0.0, 0.8, -3.0)),
                      "nano1": (B, (0.0, 19.2, -3.0)),  # the tower crane's hook
                      "nano2": (B, (-10.2, 12.1, -3.0)), "nano3": (B, (10.2, 12.1, -3.0))},  # the lamp masts
    # S-181 walking constructors and helpers: the emitter at the tip of the `nano` arm
    "ord_artisan": {"nano1": (N, (1.45, 4.6, -2.2))},
    "chs_tinker": {"nano1": (N, (0.95, 5.4, -2.65))},
    "ord_lazarus": {"nano1": (N, (-1.45, 4.5, -2.05))},
    "chs_graverobber": {"nano1": (N, (1.45, 3.35, -3.0))},
}


def for_unit(unit_id):
    """rig.json `attachments` entries for `unit_id` ({} if none)."""
    return {name: {"parent": parent, "at": list(at)} for name, (parent, at) in ANCHORS.get(unit_id, {}).items()}


def patch():
    """Writes the anchors into every existing export/rig.json (no rebuild)."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for uid in sorted(ANCHORS):
        path = os.path.join(root, uid, "export", "rig.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            rig = json.load(f)
        rig.setdefault("attachments", {}).update(for_unit(uid))
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(rig, indent=2) + "\n")
        print(f"patched {uid}")


if __name__ == "__main__" and "--patch" in sys.argv:
    patch()
