"""Minimal PNG writer for numpy arrays (Blender's Python has numpy, no PIL)."""

import struct
import zlib

import numpy as np


def write(path, a):
    """a: uint8 array, (h, w) grey, (h, w, 3) RGB or (h, w, 4) RGBA."""
    a = np.ascontiguousarray(a, dtype=np.uint8)
    h, w = a.shape[:2]
    ch = 1 if a.ndim == 2 else a.shape[2]
    ctype = {1: 0, 3: 2, 4: 6}[ch]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))

