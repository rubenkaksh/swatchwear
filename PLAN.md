# Swatchwear — build plan

## Core user flow
1. Add portrait (gallery/camera; upper body, plain-ish top works best)
2. Auto cutout (~1 s, on device)
3. Refine (brush/eraser; region: top only / top + sleeves / full outfit)
4. Live try-on (camera fabric fills garment; pinch/drag; shading slider)
5. Capture → save to Looks, share, compare 2-up

## Data model
| Entity | Fields | Files |
|---|---|---|
| Portrait | id, name, createdAt, maskVersion, regionMode | original.jpg, mask.png, shading.png, thumb.jpg |
| MaskEdit | portraitId, strokes (JSON: type, width, points) | — |
| Look | id, portraitId, title, tags, createdAt, shadingStrength | look.jpg, thumb.jpg |

## Risks & spikes
| Risk | Spike | Fallback |
|---|---|---|
| Clothes mask quality | Run multiclass model on 10 real portraits | Manual brush as primary |
| Camera texture → shader cost | Stack+BlendMode vs imageStream→ui.Image→FragmentShader; measure fps | Freeze-frame mode |
| Shading looks fake on dark/patterned tops | Compare multiply vs soft-light on 5 shirt types | Shading off for busy tops |
| 16 MB model size | Try float16/int8 variants | Download model on first launch |

## Milestones

### M0 — Spikes
- [ ] Segment 10 portraits with the multiclass model, export masks
- [ ] Camera + mask compositing at ≥24 fps on a mid-range device
- [ ] Shading blend comparison

### M1 — Cutout
- [ ] Project scaffold: feature folders, flutter_bloc, drift
- [ ] Add portrait (gallery/camera) + Portraits home
- [ ] Auto mask + cleanup in isolate
- [ ] Brush/eraser editor with undo, region chips

### M2 — Live try-on
- [ ] Camera screen with portrait overlay, pinch/drag transform
- [ ] Shading map precompute + shader composite
- [ ] Shading slider, freeze, torch toggle

### M3 — Looks
- [ ] Capture → Look review → save
- [ ] Looks gallery + 2-up compare
- [ ] Share sheet export
