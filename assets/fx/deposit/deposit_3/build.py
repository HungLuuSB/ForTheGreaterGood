"""Supply deposit, variant 3 (assets/fx/deposit/deposit.py, M-28).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/deposit/deposit_3/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import deposit  # noqa: E402

deposit.run(__file__, "deposit_3", seed=23757)
