"""ord_nuke missile mesh (assets/fx/missiles/missile.py).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/missiles/ord_nuke/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import missile  # noqa: E402

missile.run(__file__, "ord_nuke")
