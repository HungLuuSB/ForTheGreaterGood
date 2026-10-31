"""Scrap heap, footprint 4 and up (assets/fx/scrap/scrap.py, S-227).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/scrap/scrap_heap_4/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import scrap  # noqa: E402

scrap.run(__file__, "scrap_heap_4", footprint=4, seed=8293)
