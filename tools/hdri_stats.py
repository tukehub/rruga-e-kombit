"""Print luminance statistics of the HDRIs under godot/assets/hdri (debug helper)."""
import glob
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from hdr_io import read_hdr  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "hdri")
for path in sorted(glob.glob(os.path.join(ROOT, "*.hdr"))):
    img = read_hdr(path)
    lum = img[..., 0] * 0.2126 + img[..., 1] * 0.7152 + img[..., 2] * 0.0722
    h = lum.shape[0]
    w = np.cos((np.arange(h) + 0.5) / h * np.pi - np.pi / 2)[:, None]
    mean = float((lum * w).sum() / (w.sum() * lum.shape[1]))
    upper = lum[: h // 2]
    print(f"{os.path.basename(path):22s} {img.shape[1]}x{img.shape[0]}  mean={mean:8.3f}  "
          f"median={np.median(lum):7.3f}  upper_mean={upper.mean():8.3f}  "
          f"p99={np.percentile(lum, 99):8.2f}  max={lum.max():10.1f}")
