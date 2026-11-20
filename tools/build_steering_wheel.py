"""Render the touch steering wheel sprite: a flat-bottomed supercar wheel.

Writes godot/assets/ui/controls/steering_wheel.png, 512x512 RGBA, drawn
procedurally (no source art, so it is ours to license): carbon-fibre top
section, perforated leather grips, brushed-metal spokes, paddle shifters
behind the horizontal spokes and a cyan 12 o'clock stripe. Rendered at 2x and
downsampled for clean edges. Lit from the upper left.

    python3 tools/build_steering_wheel.py
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "godot" / "assets" / "ui" / "controls" / "steering_wheel.png"
SIZE = 512
SS = 2
N = SIZE * SS
CYAN = np.array([0.0, 0.898, 1.0])
LIGHT = np.array([-0.45, -0.6, 0.66])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

# Geometry, in units of the image size, centre at 0, y down.
R_OUT = 0.415       # rim outer radius
R_IN = 0.315        # rim inner radius
FLAT_OUT = 0.335    # flat bottom of the rim, outer edge
FLAT_IN = 0.245     # flat bottom, inner edge
HUB_R = 0.125

rng = np.random.default_rng(7)
ys, xs = np.mgrid[0:N, 0:N]
x = (xs + 0.5) / N - 0.5
y = (ys + 0.5) / N - 0.5
r = np.hypot(x, y)
ang = np.arctan2(x, -y)  # 0 at 12 o'clock, positive clockwise


def smax(a, b, k):
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return a * h + b * (1 - h) + k * h * (1 - h)


def coverage(sdf):
    """Signed distance (image units, negative inside) to an anti-aliased mask."""
    px = 1.0 / N
    return np.clip(0.5 - sdf / (1.5 * px), 0.0, 1.0)


def shade(height, base, spec=0.35, shininess=24.0, ambient=0.35):
    gy, gx = np.gradient(height * N * 0.012)
    normal = np.stack([-gx, -gy, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    diffuse = np.clip(normal @ LIGHT, 0.0, 1.0)
    half = LIGHT + np.array([0.0, 0.0, 1.0])
    half /= np.linalg.norm(half)
    specular = np.clip(normal @ half, 0.0, 1.0) ** shininess
    return np.clip(base * (ambient + (1 - ambient) * diffuse)[..., None] + spec * specular[..., None], 0.0, 1.0)


def bar(x0, y0, x1, y1, w0, w1):
    """Distance to a tapered capsule from (x0,y0) (width w0) to (x1,y1) (w1)."""
    px, py = x - x0, y - y0
    dx, dy = x1 - x0, y1 - y0
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    d = np.hypot(px - t * dx, py - t * dy)
    return d - (w0 + (w1 - w0) * t) * 0.5, t


def rounded_box(cx, cy, hx, hy, rad):
    qx = np.abs(x - cx) - hx + rad
    qy = np.abs(y - cy) - hy + rad
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rad


rgb = np.zeros((N, N, 3))
alpha = np.zeros((N, N))


def over(color, a):
    global rgb, alpha
    rgb = color * a[..., None] + rgb * (1 - a[..., None])
    alpha = a + alpha * (1 - a)


# --- paddle shifters, behind everything, peeking out past the rim
for side in (-1, 1):
    d = rounded_box(side * 0.385, -0.01, 0.075, 0.105, 0.035)
    a = coverage(d)
    h = np.clip(-d * 30, 0, 1) ** 0.5
    base = np.full((N, N, 3), 0.10) + 0.05 * (rng.random((N, N, 1)) - 0.5)
    over(shade(h, base, spec=0.5, shininess=40), a)
    # A cyan edge light on the paddle's outer face.
    edge = coverage(np.abs(d + 0.006) - 0.0025) * (side * x > 0.40)
    over(np.broadcast_to(CYAN * 0.8, (N, N, 3)), edge * 0.55)

# --- spokes (brushed metal): left, right and down to the flat bottom
spokes = []
for side in (-1, 1):
    d, t = bar(side * 0.08, 0.02, side * (R_IN + 0.03), 0.035, 0.15, 0.10)
    spokes.append((d, t))
d_down, t_down = bar(0.0, 0.08, 0.0, FLAT_IN + 0.03, 0.11, 0.085)
spokes.append((d_down, t_down))
spoke_sdf = np.minimum.reduce([s[0] for s in spokes])
a = coverage(spoke_sdf)
height = (np.clip(-spoke_sdf * 40, 0, 1) ** 0.5) * 2.0
streak = rng.normal(0, 1, (N, 1)) * 0.5 + rng.normal(0, 1, (1, N)) * 0.15
brushed = 0.48 + 0.08 * np.tanh(np.repeat(rng.normal(0, 1, (N, 1)), N, axis=1) * 0.6) + 0.03 * rng.normal(0, 1, (N, N))
base = np.stack([brushed * 0.95, brushed * 0.98, brushed * 1.02], axis=-1)
over(shade(height, base * 1.15, spec=0.8, shininess=35, ambient=0.4), a)
# Dark inlay along the side spokes.
inlay = np.minimum(bar(-0.11, 0.025, -(R_IN - 0.01), 0.033, 0.03, 0.022)[0], bar(0.11, 0.025, R_IN - 0.01, 0.033, 0.03, 0.022)[0])
over(np.broadcast_to(np.array([0.05, 0.06, 0.07]), (N, N, 3)), coverage(inlay) * 0.9)

# --- rim
outer = smax(r - R_OUT, y - FLAT_OUT, 0.05)
inner = smax(r - R_IN, y - FLAT_IN, 0.05)
rim = np.maximum(outer, -inner)
a = coverage(rim)
# Tube profile across the rim: a half-round section, highest mid-rim.
half_width = 0.05
t = np.clip(-rim / half_width, 0, 1)
tube = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) * 2.2
top = (np.abs(ang) < np.radians(52)) & (y < 0)
bottom = y > 0.18
# Carbon fibre: a fine 2x2 twill.
u = (x + y) * 180.0
v = (x - y) * 180.0
twill = ((np.floor(u) + np.floor(v * 0.5)) % 2)
carbon = 0.07 + 0.06 * twill[..., None] * np.array([1.0, 1.05, 1.15])
carbon = carbon + 0.03 * np.sin(u * np.pi)[..., None]
# Perforated leather: a soft dot grid on a dark warm grey.
gx = (x * 150.0) % 1.0 - 0.5
gy = (y * 150.0) % 1.0 - 0.5
dots = (np.hypot(gx, gy) < 0.2).astype(float)
leather = (0.12 + 0.02 * rng.normal(0, 1, (N, N)))[..., None] * np.array([1.0, 0.97, 0.95]) - 0.05 * dots[..., None]
base = np.where(top[..., None] | bottom[..., None], carbon, leather)
lit = shade(tube, base * 1.6, spec=0.55, shininess=18, ambient=0.28)
over(lit, a)
# Stitching where carbon meets leather: thin light seams across the rim.
for edge_ang in (-52, 52):
    seam = np.abs(np.degrees(ang) - edge_ang) < 0.7
    over(np.broadcast_to(np.array([0.35, 0.36, 0.4]), (N, N, 3)), a * seam * 0.5)
# The 12 o'clock stripe.
stripe = coverage(np.maximum(np.abs(x) - 0.017, rim)) * (y < 0)
over(np.broadcast_to(CYAN, (N, N, 3)), stripe)
glow = coverage(np.maximum(np.abs(x) - 0.03, rim)) * (y < 0) * 0.25
over(np.broadcast_to(CYAN, (N, N, 3)), glow * (1 - stripe))

# --- hub
d_hub = r - HUB_R
a = coverage(d_hub)
h = np.clip(-d_hub * 14, 0, 1) ** 0.5
base = np.full((N, N, 3), 0.08)
over(shade(h, base, spec=0.4, shininess=30), a)
ring = coverage(np.abs(r - HUB_R + 0.012) - 0.006)
over(shade(np.full((N, N), 0.5), np.full((N, N, 3), 0.55), spec=0.6, shininess=50), ring)
# A small silver V for the badge.
v_left = bar(-0.04, -0.03, 0.0, 0.035, 0.018, 0.018)[0]
v_right = bar(0.04, -0.03, 0.0, 0.035, 0.018, 0.018)[0]
over(np.broadcast_to(np.array([0.82, 0.85, 0.88]), (N, N, 3)), coverage(np.minimum(v_left, v_right)))

# Soft contact shadow under everything, for legibility over a bright road.
shadow_sdf = smax(r - R_OUT - 0.01, y - FLAT_OUT - 0.01, 0.05)
shadow = np.clip(1.0 - (shadow_sdf + 0.01) / 0.035, 0, 1) * 0.35
final_a = alpha + shadow * (1 - alpha)
final_rgb = np.where(final_a[..., None] > 0, rgb * alpha[..., None] / np.maximum(final_a, 1e-6)[..., None], 0)

img = np.concatenate([final_rgb, final_a[..., None]], axis=-1)
img = img.reshape(SIZE, SS, SIZE, SS, 4).mean(axis=(1, 3))
OUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray((np.clip(img, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(OUT, optimize=True)
print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
