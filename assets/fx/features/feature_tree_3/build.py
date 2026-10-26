"""Map feature feature_tree_3 (assets/fx/features/features.py, S-197).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/features/feature_tree_3/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import features  # noqa: E402

features.run(__file__, "feature_tree_3", features.build_broadleaf(3907, 12.0, 4), height=12)
