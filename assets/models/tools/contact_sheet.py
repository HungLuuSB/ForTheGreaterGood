"""Tiles same-sized PNGs (the units' Blender previews) into one review sheet:

    blender -b --factory-startup -P assets/models/tools/contact_sheet.py -- <out.png> <cols> <png>...
"""

import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, cols, files = args[0], int(args[1]), args[2:]
tiles = []
for f in files:
    img = bpy.data.images.load(f)
    w, h = img.size
    tiles.append(np.array(img.pixels[:]).reshape(h, w, 4)[::-1, :, :3])
h, w = tiles[0].shape[:2]
rows = []
for r in range(0, len(tiles), cols):
    row = tiles[r:r + cols]
    row += [np.ones((h, w, 3))] * (cols - len(row))
    rows.append(np.concatenate(sum([[t, np.ones((h, 4, 3))] for t in row], [])[:-1], axis=1))
sheet = np.concatenate(sum([[r, np.ones((4, rows[0].shape[1], 3))] for r in rows], [])[:-1], axis=0)
H, W = sheet.shape[:2]
img = bpy.data.images.new("sheet", W, H)
rgba = np.ones((H, W, 4))
rgba[:, :, :3] = sheet
img.pixels[:] = rgba[::-1].ravel()
img.filepath_raw = out
img.file_format = "PNG"
img.save()
print("SHEET", out, W, H)
