"""Effect textures for the client (M-27, docs/contracts/fx.md "Effect
textures"): white RGB, the pattern in alpha, so the client tints them.
blender -b --factory-startup --python-exit-code 1 -P assets/fx/textures/build.py

- radar_pulse.png: a radar sweep pulse ring, a bright thin ring with a soft
  trailing glow inside it (expand it outward from the radar);
- sonar_ping.png: a sonar ping, two soft concentric rings (expand and fade);
- jammer_static.png: jammer shimmer / static, tileable speckle and scan lines;
- heat_shimmer.png: heat shimmer, tileable soft wavy bands (scroll it upward
  over exhausts, stacks and beam emitters).
"""

import math
import os
import random

import bpy
import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
N = 512


def save(name, alpha):
    img = bpy.data.images.new(name, N, N, alpha=True)
    px = np.ones((N, N, 4), dtype=np.float32)
    px[:, :, 3] = np.clip(alpha, 0.0, 1.0)
    img.pixels[:] = px.ravel()
    path = os.path.join(OUT, name + ".png")
    scene = bpy.context.scene
    s = scene.render.image_settings
    s.file_format, s.color_mode, s.color_depth = "PNG", "RGBA", "8"
    img.save_render(path, scene=scene)
    print("wrote", path)


y, x = np.mgrid[0:N, 0:N].astype(np.float32)
u, v = (x + 0.5) / N * 2 - 1, (y + 0.5) / N * 2 - 1
r = np.sqrt(u * u + v * v)

# radar pulse: a thin bright ring at r = 0.9 and a soft glow trailing inward
ring = np.exp(-((r - 0.9) / 0.018) ** 2)
trail = np.where(r < 0.9, np.exp(-((0.9 - r) / 0.22)) * 0.35, 0.0)
save("radar_pulse", (ring + trail) * (r < 0.99))

# sonar ping: two soft concentric rings
ping = np.exp(-((r - 0.88) / 0.03) ** 2) + 0.55 * np.exp(-((r - 0.72) / 0.03) ** 2)
save("sonar_ping", ping * (r < 0.99))

# jammer static: speckle on a tileable cell grid plus soft scan lines
rng = random.Random(7)
cells = np.array([[rng.random() for _ in range(128)] for _ in range(128)], dtype=np.float32)
speck = np.kron(cells, np.ones((4, 4), dtype=np.float32))
speck = np.where(speck > 0.62, (speck - 0.62) / 0.38, 0.0)
scan = 0.5 + 0.5 * np.sin(y / N * 2 * math.pi * 24)
save("jammer_static", np.clip(speck * 0.9 + 0.18 * scan * (speck > 0), 0, 1))

# heat shimmer: tileable wavy bands (sums of whole-period sines), soft and low
w = (np.sin(2 * math.pi * (y / N * 6 + 0.15 * np.sin(2 * math.pi * x / N * 3)))
     + 0.6 * np.sin(2 * math.pi * (y / N * 11 + 0.2 * np.sin(2 * math.pi * x / N * 5 + 1.3))))
save("heat_shimmer", 0.25 + 0.2 * w / 1.6)
