# M0 spike 1 — clothes mask quality

Question: is the MediaPipe multiclass clothes mask good enough on real portraits, or is manual brush the primary tool?

## Run
1. Drop 10 real upper-body portraits (JPG/PNG, not HEIC) in `portraits/`. Mix: plain top, patterned top, dark top, jacket over shirt, long sleeves, short sleeves, hair over shoulders, two different skin tones, one bad-light shot, one with a bag strap or necklace. (`mp_sample.jpg` is MediaPipe's own test image, delete it before the real run.)
2. `.venv/bin/python segment.py` -> `out/<name>_mask.png`, `<name>_overlay.jpg`, `contact_sheet.jpg`, `metrics.csv`.
3. Look at the contact sheet and score each portrait: good (use as is), fixable (under ~1 min of brush), bad (redo by hand).

## Decision rule (proposed, adjust if you disagree)
- 8 or more of 10 good/fixable: auto cutout stays primary, brush is touch-up.
- 5-7: auto is a starting point, ship the brush as a first-class tool and drop the "96%" style claims.
- Under 5: brush-first, auto becomes "suggest".

## Metrics (`metrics.csv`)
`clothes_pct` area of the clothes class; `kept_pct` how much of it is the largest component (low = fragmented); `components_over_0p5pct` count of separate blobs; `compactness` ragged/holey edges score (1 = circle, low = noisy); `fill_holes_px` pixels a 15 px close would fill; `mean_conf` model confidence inside the mask. Metrics flag trouble, the contact sheet is the verdict.

## Setup notes
Python 3.10 venv with mediapipe 1.2.0, pillow, numpy, opencv-headless. Model `selfie_multiclass_256x256.tflite` (16.4 MB float32) downloaded from storage.googleapis.com/mediapipe-models. `.venv/` and the model are not meant to be committed.

## Status (2026-10-29)
Run 1 (7 stock images) and Run 2 (13 of the user's own phone photos, `portraits/spike2/`, local only) are done, see below. Not yet tried: float16/int8 variants (PLAN risk "16 MB model size"), `tflite_flutter` / `face_detection_tflite` parity (this spike uses the Python reference).

## Run 1 results (2026-10-29, 7 Wikimedia Commons images, see portraits/SOURCES.csv)
Only 7 of 10 slots filled (no hits for plain light tee, blazer-over-shirt, knit). Eyeballed on `out/contact_sheet.jpg`:

| # | Case | Verdict | Note |
|---|------|---------|------|
| 01 | Suit, studio | good | Clean edges; pocket square excluded |
| 02 | Striped top, cropped, bandana | bad | Shirt mostly out of frame; mask fragmented (kept 45%) |
| 03 | 1900s photo, floral blouse | fixable | Mask bleeds into dark vignette at the bottom |
| 04 | Striped sweater, mirror selfie | good | Sweater clean; includes trousers |
| 05 | Black leather jacket | good | Clean; hair strands over the shoulder cut out correctly |
| 06 | White top, full body | good | Holes at the belt; includes leggings |
| 07 | Polo, dim light | good | Ignores the second person's shirt |

Result: 5 good, 1 fixable, 1 bad of 7 (about 86% usable), which clears the proposed 8-of-10 bar on this small set. Not conclusive: studio-heavy, no hand-held phone shots.
Finding that matters for design: class 4 is all clothing, so trousers come with the top (04, 06). "Top only" needs a torso crop, not just a threshold. Cropped framing (02) wrecks the mask, so the Add-portrait hint should say "include your whole upper body".
Metrics did not predict quality (06 has compactness 0.38 yet is good); use the contact sheet.

## Run 2 results (2026-10-29, 13 user phone photos, `out/spike2/contact_sheet.jpg`)
Eyeballed on 256 px thumbnails (not zoomed), so edge detail is unverified.

| # | Case | Verdict | Note |
|---|------|---------|------|
| 01 | Seated, sunlit room, sage tee | good | Tee clean; includes trousers |
| 02 | Fitting-room mirror selfie, cream shirt | good | Includes shorts; textured weave fine |
| 03 | Night, cap, grey denim hoodie | fixable | Patchy at the lower body and arm; busy lights did not hurt |
| 04 | Mirror in frame, dark shirt | fixable | Shirt and trousers found; ragged lower left (bag/dark object) |
| 05 | Black leather jacket, indoor | fixable | Jacket good; backpack strap bled in, trousers not included |
| 06 | Mirror selfie, black puffer | good | Red tee under the jacket is included |
| 07 | Standing on bridge, navy jacket | good | Includes trousers |
| 08 | Striped pyjamas, doorway | good | Fine stripes OK |
| 09 | Group of 8 | bad | Fragmented, several people half-masked |
| 10 | Polo, mountains | good | Includes trousers |
| 11 | Group of 7, wide | bad | Only part of the people (kept 56%) |
| 12 | Grey patterned tee, blurry street | good | Motion blur OK |
| 13 | Couple against brick | fixable | Both people masked; needs to pick one person |

Single-person photos: 10 of 10 good or fixable (7 good, 3 fixable). Group photos: 0 of 2 usable, couple needs a person picker.
Combined with Run 1: auto cutout stays primary for single-person portraits, brush is touch-up (decision rule: 8+ of 10).
Findings for design: (1) class 4 includes trousers, so "Top only" needs a torso crop, in 7 of 10 full-body shots; (2) multi-person photos need a "tap the person" step or a hint to use one person; (3) mirror selfies work, even with the phone and a gilt frame; (4) dark and patterned tops were not the problem, bags and straps were.
Not tested: HEIC input, very low light, skin-tone range beyond these photos.
