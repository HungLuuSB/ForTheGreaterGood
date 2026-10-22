"""Supply deposit, variant 2 (assets/fx/deposit/deposit.py, M-28).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/deposit/deposit_2/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import deposit  # noqa: E402

deposit.run(__file__, "deposit_2", seed=15838)
