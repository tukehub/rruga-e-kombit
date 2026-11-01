"""Minimal Radiance .hdr (RGBE, RLE) reader/writer in numpy. No external deps."""
from __future__ import annotations

import numpy as np


def read_hdr(path: str) -> np.ndarray:
    """Return float32 array (h, w, 3) in linear radiance."""
    with open(path, "rb") as f:
        data = f.read()
    pos = 0
    # header lines until blank line
    while True:
        nl = data.index(b"\n", pos)
        line = data[pos:nl]
        pos = nl + 1
        if line.strip() == b"":
            break
    nl = data.index(b"\n", pos)
    res = data[pos:nl].split()
    pos = nl + 1
    # only the common -Y h +X w orientation is supported
    h = int(res[1])
    w = int(res[3])
    buf = np.frombuffer(data, dtype=np.uint8, offset=pos)
    img = np.empty((h, w, 4), dtype=np.uint8)
    p = 0
    for y in range(h):
        if buf[p] == 2 and buf[p + 1] == 2 and (int(buf[p + 2]) << 8 | int(buf[p + 3])) == w and w >= 8 and w < 32768:
            p += 4
            for c in range(4):
                x = 0
                row = img[y, :, c]
                while x < w:
                    count = int(buf[p])
                    p += 1
                    if count > 128:
                        count -= 128
                        row[x:x + count] = buf[p]
                        p += 1
                    else:
                        row[x:x + count] = buf[p:p + count]
                        p += count
                    x += count
        else:  # flat (uncompressed) scanline
            img[y] = buf[p:p + w * 4].reshape(w, 4)
            p += w * 4
    rgbe = img.astype(np.float32)
    e = rgbe[..., 3]
    scale = np.where(e > 0, np.ldexp(1.0, (e - 136.0).astype(np.int32)), 0.0).astype(np.float32)
    return rgbe[..., :3] * scale[..., None]


def write_hdr(path: str, img: np.ndarray) -> None:
    """Write float32 (h, w, 3) as RLE-compressed Radiance .hdr."""
    img = np.maximum(img, 0.0).astype(np.float32)
    h, w, _ = img.shape
    mx = img.max(axis=2)
    man, ex = np.frexp(mx)
    scale = np.where(mx > 1e-32, man * 256.0 / np.maximum(mx, 1e-32), 0.0)
    rgbe = np.zeros((h, w, 4), dtype=np.uint8)
    rgbe[..., :3] = np.clip(img * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(mx > 1e-32, ex + 128, 0).astype(np.uint8)
    out = bytearray()
    out += b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n"
    out += f"-Y {h} +X {w}\n".encode()
    for y in range(h):
        out += bytes([2, 2, (w >> 8) & 0xFF, w & 0xFF])
        for c in range(4):
            out += _rle(rgbe[y, :, c].tobytes())
    with open(path, "wb") as f:
        f.write(out)


def _rle(row: bytes) -> bytes:
    out = bytearray()
    n = len(row)
    i = 0
    while i < n:
        # run?
        run = 1
        while i + run < n and run < 127 and row[i + run] == row[i]:
            run += 1
        if run >= 4:
            out += bytes([128 + run, row[i]])
            i += run
            continue
        # literal: extend until a run of >=4 starts or 128 bytes
        j = i + 1
        while j < n and j - i < 128:
            r = 1
            while j + r < n and r < 4 and row[j + r] == row[j]:
                r += 1
            if r >= 4:
                break
            j += 1
        out += bytes([j - i]) + row[i:j]
        i = j
    return bytes(out)
