"""M0 spike 1: run the MediaPipe multiclass selfie model on portraits and export clothes masks.

Usage: .venv/bin/python segment.py [portraits_dir] [out_dir]
Classes: 0 background, 1 hair, 2 body-skin, 3 face-skin, 4 clothes, 5 others.
Pipeline mirrors CLAUDE.md: clothes channel -> upscale -> threshold 0.5 -> largest component.
"""
import csv
import sys
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

HERE = Path(__file__).parent
CLOTHES = 4
THRESH = 0.5
MIN_COMPONENT = 0.005  # a component under 0.5% of the image counts as noise, not a second garment

src = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "portraits"
out = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "out"
out.mkdir(exist_ok=True)

opts = vision.ImageSegmenterOptions(
    base_options=mp_python.BaseOptions(model_asset_path=str(HERE / "selfie_multiclass_256x256.tflite")),
    output_confidence_masks=True,
    output_category_mask=False,
)

rows, tiles = [], []
with vision.ImageSegmenter.create_from_options(opts) as seg:
    for p in sorted(src.glob("*")):
        if p.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp", ".heic"}:
            continue
        bgr = cv2.imread(str(p))
        if bgr is None:
            print(f"skip {p.name}: unreadable (convert HEIC to JPG first)")
            continue
        h, w = bgr.shape[:2]
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        res = seg.segment(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
        conf = res.confidence_masks[CLOTHES].numpy_view().astype(np.float32)
        conf = cv2.resize(conf, (w, h), interpolation=cv2.INTER_LINEAR)
        mask = (conf >= THRESH).astype(np.uint8)

        n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
        areas = stats[1:, cv2.CC_STAT_AREA]
        total = float(mask.sum())
        big = int((areas >= MIN_COMPONENT * h * w).sum()) if n > 1 else 0
        largest = int(np.argmax(areas)) + 1 if n > 1 else 0
        main = (labels == largest).astype(np.uint8) if largest else mask
        cnts, _ = cv2.findContours(main, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        perim = sum(cv2.arcLength(c, True) for c in cnts)
        area = float(main.sum())
        # 4*pi*A/P^2 = 1 for a circle; low values mean ragged edges or holes
        compact = (4 * np.pi * area / (perim**2)) if perim else 0.0
        holes = int(((cv2.morphologyEx(main, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8)) - main) > 0).sum())
        # mean confidence inside the mask: low means the model was unsure
        mean_conf = float(conf[main > 0].mean()) if area else 0.0

        cv2.imwrite(str(out / f"{p.stem}_mask.png"), main * 255)
        ov = bgr.copy()
        ov[main > 0] = (0.55 * ov[main > 0] + 0.45 * np.array([74, 249, 215])).astype(np.uint8)  # chartreuse (BGR)
        cv2.imwrite(str(out / f"{p.stem}_overlay.jpg"), ov)
        tiles.append(cv2.resize(ov, (256, int(256 * h / w))))

        rows.append(dict(
            file=p.name, size=f"{w}x{h}",
            clothes_pct=round(100 * total / (h * w), 1),
            kept_pct=round(100 * area / total, 1) if total else 0,
            components_over_0p5pct=big,
            compactness=round(compact, 3),
            fill_holes_px=holes,
            mean_conf=round(mean_conf, 3),
        ))

if rows:
    with open(out / "metrics.csv", "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=rows[0].keys())
        wr.writeheader()
        wr.writerows(rows)
    th = max(t.shape[0] for t in tiles)
    pad = [cv2.copyMakeBorder(t, 0, th - t.shape[0], 0, 0, cv2.BORDER_CONSTANT) for t in tiles]
    per_row = 5
    while len(pad) % per_row:
        pad.append(np.zeros_like(pad[0]))
    sheet = np.vstack([np.hstack(pad[i:i + per_row]) for i in range(0, len(pad), per_row)])
    cv2.imwrite(str(out / "contact_sheet.jpg"), sheet)
    for r in rows:
        print(r)
else:
    print(f"no portraits found in {src}; drop 10 real upper-body portraits there")
