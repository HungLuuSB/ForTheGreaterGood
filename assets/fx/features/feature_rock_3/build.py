"""Map feature feature_rock_3 (assets/fx/features/features.py, S-197).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/features/feature_rock_3/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import features  # noqa: E402

features.run(__file__, "feature_rock_3", features.build_rock(9127, 7.4, 5.4, 1, lichen=0.12), height=8)
