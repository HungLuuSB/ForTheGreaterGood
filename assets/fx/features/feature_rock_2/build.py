"""Map feature feature_rock_2 (assets/fx/features/features.py, S-197).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/features/feature_rock_2/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import features  # noqa: E402

features.run(__file__, "feature_rock_2", features.build_rock(7823, 6.6, 3.6, 3, lichen=0.28), height=8)
