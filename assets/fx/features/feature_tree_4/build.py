"""Map feature feature_tree_4 (assets/fx/features/features.py, S-197).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/features/feature_tree_4/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import features  # noqa: E402

features.run(__file__, "feature_tree_4", features.build_broadleaf(5209, 10.5, 3), height=10.5)
