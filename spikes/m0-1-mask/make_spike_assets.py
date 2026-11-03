"""Build spike-2 assets from a portrait + its spike-1 mask.
Usage: make_spike_assets.py portrait.jpg mask.png out_dir [waist_fraction=0.47]
Outputs: cutout_{both,torso,legs}.png (RGBA, selected garment part transparent), shading.png (blurred luminance/mean, <=1), shading_mul.png (clipped to 1).
Torso/legs split is a straight horizontal cut at waist_fraction of the mask's bounding-box height (spike hack, not a real garment split).
"""
import sys
import cv2
import numpy as np

src, mask_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
waist = float(sys.argv[4]) if len(sys.argv) > 4 else 0.47
W = 750
img = cv2.imread(src)
m0 = cv2.imread(mask_path, 0)
h, w = img.shape[:2]
H = int(h * W / w)
img = cv2.resize(img, (W, H), interpolation=cv2.INTER_AREA)
m0 = cv2.resize(m0, (W, H), interpolation=cv2.INTER_AREA)
ys = np.where((m0 > 127).any(axis=1))[0]
split = int(ys[0] + waist * (ys[-1] - ys[0]))
rows = np.arange(H)[:, None]
parts = {"both": np.ones((H, 1)), "torso": (rows < split).astype(np.float32), "legs": (rows >= split).astype(np.float32)}

def soft(m):
    return cv2.GaussianBlur(cv2.dilate(m, np.ones((5, 5), np.uint8)), (0, 0), 1.5).astype(np.float32) / 255.0

lum = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
ms = soft(m0)
mean = lum[ms > 0.5].mean()
for name, sel in parts.items():
    m = soft((m0 * sel).astype(np.uint8))
    cv2.imwrite(f"{out_dir}/cutout_{name}.png", np.dstack([img, ((1 - m) * 255).astype(np.uint8)]))
# shader shading: darken-only, low-pass (normalised blur inside the mask) so broad folds survive but fabric-like detail of the old garment does not
SIGMA = 10
r = np.clip(lum / mean, 0, 1)
blur = cv2.GaussianBlur(r * ms, (0, 0), SIGMA) / np.maximum(cv2.GaussianBlur(ms, (0, 0), SIGMA), 1e-3)
shade = np.clip(blur, 0, 1) * 255  # ratio <= 1, shader uses it directly
cv2.imwrite(f"{out_dir}/shading.png", (shade * ms + 255 * (1 - ms)).astype(np.uint8))
mul = np.clip(lum / mean, 0, 1) * 255
cv2.imwrite(f"{out_dir}/shading_mul.png", (mul * ms + 255 * (1 - ms)).astype(np.uint8))
cv2.imwrite(f"{out_dir}/portrait.jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 92])
print("ok", W, H, "split row", split, "mean lum", round(float(mean), 1))
