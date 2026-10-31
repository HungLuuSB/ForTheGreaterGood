"""Scrap heap, footprint 1 (assets/fx/scrap/scrap.py, S-227).
blender -b --factory-startup --python-exit-code 1 -P assets/fx/scrap/scrap_heap_1/build.py
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import scrap  # noqa: E402

scrap.run(__file__, "scrap_heap_1", footprint=1, seed=5254)
