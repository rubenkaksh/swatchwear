"""Generate tileable stock fabric swatches into assets/fabrics/ (1024x1024 JPG).
Usage: make_fabrics.py [out_dir]   (needs numpy + opencv; reuse spikes/m0-1-mask/.venv)
All patterns are periodic so they tile without seams.
"""
import sys
from pathlib import Path

import cv2
import numpy as np

N = 1024
out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "assets" / "fabrics"
out.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)


def wrap_blur(a, s):
    # OpenCV has no wrap border for blur: pad periodically, blur, crop
    pad = int(s * 4) + 2
    p = np.pad(a, pad, mode="wrap")
    return cv2.GaussianBlur(p, (0, 0), s)[pad:-pad, pad:-pad]


def noise(s, seed=0):
    r = np.random.default_rng(seed).standard_normal((N, N)).astype(np.float32)
    n = wrap_blur(r, s)
    return (n - n.mean()) / (n.std() + 1e-6)


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32)[::-1]  # BGR


def paint(mask, color, base):
    return base * (1 - mask[..., None]) + color * mask[..., None]


def weave(img, strength=14, period=4):
    """Fine woven grain: thread-level checker plus noise."""
    grain = (np.sin(xx * 2 * np.pi / period) * np.sin(yy * 2 * np.pi / period)) * 0.5 + noise(0.8, 1) * 0.5
    return np.clip(img + grain[..., None] * strength, 0, 255)


def save(name, img):
    cv2.imwrite(str(out / f"{name}.jpg"), np.clip(img, 0, 255).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 90])


def denim():
    base = np.ones((N, N, 3), np.float32) * rgb("#27407a")
    twill = np.sin((xx + yy) * 2 * np.pi / 8) * 0.5 + 0.5
    warp = np.sin(xx * 2 * np.pi / 3) * 0.5 + 0.5
    fade = noise(40, 3) * 0.5 + noise(6, 4) * 0.5
    lum = 0.72 + 0.22 * twill + 0.12 * warp + 0.10 * fade
    img = base * lum[..., None]
    img[..., 2] += 8 * noise(1.2, 5)  # lighter slubs
    return weave(img, 6, 3)


def houndstooth():
    u, v = (xx % 128) / 128, (yy % 128) / 128
    # classic tooth: checker of 4 cells, each cell sheared into points
    cx, cy = (xx // 32 + yy // 32) % 2, 0
    lx, ly = (xx % 32) / 32, (yy % 32) / 32
    tooth = ((lx + ly) % 1.0 < 0.5).astype(np.float32)
    dark = np.where(((xx // 32 + yy // 32) % 2) == 0, tooth, 1 - tooth)
    dark = wrap_blur(dark, 0.8)
    img = paint(dark, rgb("#1c1c1e"), np.ones((N, N, 3), np.float32) * rgb("#ebe7df"))
    return weave(img, 10, 4)


def tartan():
    def stripes(t):
        s = np.zeros_like(t)
        s += ((t % 256) < 64) * 1.0  # wide band
        s += (((t + 96) % 256) < 8) * 2.0  # thin accent
        s += (((t + 160) % 256) < 16) * 3.0
        return s

    cols = {0: rgb("#7a1722"), 1: rgb("#143d2a"), 2: rgb("#e7d9a6"), 3: rgb("#0e1326")}
    sx, sy = stripes(xx), stripes(yy)
    base = np.ones((N, N, 3), np.float32) * cols[0]
    for k, c in ((1, cols[1]), (2, cols[2]), (3, cols[3])):
        mx, my = (sx == k).astype(np.float32), (sy == k).astype(np.float32)
        base = paint(np.maximum(mx, my) * 0.85, c, base)
        base = paint(mx * my * 0.9, c * 0.7, base)
    twill = np.sin((xx + yy) * 2 * np.pi / 6) * 0.5 + 0.5
    base *= (0.85 + 0.2 * twill)[..., None]
    return weave(base, 8, 3)


def breton():
    band = ((yy % 128) < 64).astype(np.float32)
    band = wrap_blur(band, 1.0)
    img = paint(band, rgb("#f4f1ea"), np.ones((N, N, 3), np.float32) * rgb("#1f2d55"))
    rib = np.sin(xx * 2 * np.pi / 6) * 0.5 + 0.5  # jersey knit ribs
    img *= (0.88 + 0.16 * rib)[..., None]
    return weave(img, 7, 3)


def gingham():
    a = ((xx % 128) < 64).astype(np.float32)
    b = ((yy % 128) < 64).astype(np.float32)
    shade = np.clip(a * 0.5 + b * 0.5, 0, 1)  # 0 white, .5 light, 1 dark
    base = np.ones((N, N, 3), np.float32) * rgb("#f6f2ea")
    base = paint(shade, rgb("#c0392b"), base)
    base = paint(a * b * 0.0 + (a * b) * 0.45, rgb("#7a1b12"), base)
    return weave(base, 9, 4)


def camo():
    n1, n2, n3 = noise(30, 11), noise(18, 12), noise(10, 13)
    base = np.ones((N, N, 3), np.float32) * rgb("#6b7040")
    base = paint((n1 > 0.2).astype(np.float32), rgb("#3b4126"), base)
    base = paint((n2 > 0.55).astype(np.float32), rgb("#8b7a50"), base)
    base = paint((n3 > 1.0).astype(np.float32), rgb("#1f2214"), base)
    return weave(base, 8, 3)


def leopard():
    base = np.ones((N, N, 3), np.float32) * rgb("#c8923e")
    base *= (0.92 + 0.1 * noise(30, 21))[..., None]
    mask_ring = np.zeros((N, N), np.float32)
    mask_core = np.zeros((N, N), np.float32)
    for _ in range(95):
        cx, cy = rng.integers(0, N), rng.integers(0, N)
        r = rng.integers(14, 30)
        ang = rng.uniform(0, 180)
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                c = (int(cx + dx), int(cy + dy))
                cv2.ellipse(mask_core, c, (int(r * .95), int(r * .7)), ang, 0, 360, 1.0, -1)
                # broken ring: open arc on one side
                a0 = rng.uniform(0, 360)
                cv2.ellipse(mask_ring, c, (int(r * 1.5), int(r * 1.15)), ang, a0, a0 + 250, 1.0, int(r * .45))
    core = wrap_blur(mask_core, 2)
    ring = wrap_blur(mask_ring, 1.5)
    base = paint(core * 0.9, rgb("#7c4b1c"), base)
    base = paint(ring * 0.95, rgb("#17110c"), base)
    return weave(base, 6, 3)


def floral():
    base = np.ones((N, N, 3), np.float32) * rgb("#1d2a3a")
    base *= (0.9 + 0.12 * noise(25, 31))[..., None]
    petals = np.zeros((N, N, 3), np.float32)
    pal = [rgb("#e86a7d"), rgb("#f2b8c6"), rgb("#f4c95d"), rgb("#f6efe4")]
    layer = np.zeros((N, N), np.float32)
    for _ in range(46):
        cx, cy = rng.integers(0, N), rng.integers(0, N)
        r = rng.integers(34, 56)
        col = pal[rng.integers(0, len(pal))]
        rot = rng.uniform(0, 72)
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                m = np.zeros((N, N), np.float32)
                for k in range(5):
                    a = np.deg2rad(rot + k * 72)
                    c = (int(cx + dx + np.cos(a) * r * .55), int(cy + dy + np.sin(a) * r * .55))
                    cv2.ellipse(m, c, (int(r * .55), int(r * .35)), np.rad2deg(a), 0, 360, 1.0, -1)
                m = wrap_blur(m, 1.2)
                base = paint(m * 0.95, col, base)
                cv2.circle(layer, (cx + dx, cy + dy), int(r * .18), 1.0, -1)
    base = paint(wrap_blur(layer, 1.0), rgb("#c98a1a"), base)
    return weave(base, 8, 3)


def corduroy():
    rib = np.sin(xx * 2 * np.pi / 14) * 0.5 + 0.5
    base = np.ones((N, N, 3), np.float32) * rgb("#b5822f")
    base *= (0.62 + 0.5 * rib)[..., None]
    base *= (0.94 + 0.08 * noise(0.7, 41))[..., None]
    return base


def herringbone():
    cell = 48
    col = (xx // cell).astype(np.int32)
    local_y = (yy + np.where(col % 2 == 0, 0, 0)).astype(np.float32)
    # chevron: diagonal stripe direction flips every column
    d = np.where(col % 2 == 0, (xx % cell) + local_y, (xx % cell) * -1 + local_y + cell)
    band = (np.mod(d, 24) < 12).astype(np.float32)
    band = wrap_blur(band, 0.7)
    img = paint(band, rgb("#8d8a80"), np.ones((N, N, 3), np.float32) * rgb("#3a3b3a"))
    img *= (0.9 + 0.2 * noise(1.0, 51))[..., None]
    return weave(img, 8, 3)


def polka():
    base = np.ones((N, N, 3), np.float32) * rgb("#1b2e4b")
    m = np.zeros((N, N), np.float32)
    for gy in range(0, N, 128):
        for gx in range(0, N, 128):
            off = 64 if (gy // 128) % 2 else 0
            cv2.circle(m, (gx + off + 32, gy + 32), 22, 1.0, -1)
            cv2.circle(m, (gx + off + 32 - N, gy + 32), 22, 1.0, -1)
    m = wrap_blur(m, 1.0)
    base = paint(m, rgb("#f1ede4"), base)
    return weave(base, 8, 3)


FABRICS = dict(denim=denim, houndstooth=houndstooth, tartan=tartan, breton=breton, gingham=gingham,
               camo=camo, leopard=leopard, floral=floral, corduroy=corduroy, herringbone=herringbone, polka=polka)

if __name__ == "__main__":
    tiles = []
    for name, fn in FABRICS.items():
        img = fn()
        save(name, img)
        tiles.append(cv2.resize(np.clip(img, 0, 255).astype(np.uint8), (256, 256)))
        print("ok", name)
    while len(tiles) % 4:
        tiles.append(np.zeros_like(tiles[0]))
    sheet = np.vstack([np.hstack(tiles[i:i + 4]) for i in range(0, len(tiles), 4)])
    if len(sys.argv) > 2:
        cv2.imwrite(sys.argv[2], sheet)
