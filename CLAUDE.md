# Swatchwear — fabric try-on app (Flutter)

Handoff from a planning session in the Claude app (2026-10-29). Read this file, `PLAN.md` and `design/README.md` before starting work.

## What we're building
This app turns a social-media trend into software. In the trend, people print a portrait, cut the shirt out of it, and hold the paper over a fabric in a store so the fabric looks like their outfit.
App version: cut the clothing out of a portrait photo, then show the **live camera feed** (pointed at fabric) through that cutout, with the original garment's folds/shadows blended on top so it looks worn.

## Decisions already made (don't re-ask)
- **Fabric source:** live camera only (no fabric library, no snapped photos in v1).
- **Cutout:** auto segmentation + manual brush/eraser touch-up.
- **Realism:** flat fabric + shading blend (multiply/soft-light of the original garment's luminance). No generative AI.
- **Scope:** personal MVP, fully offline, iOS + Android, no accounts/backend. Save + share snapshots.
- **State management:** Bloc (flutter_bloc). Feature-first folders.
- **Working name:** Swatch / Swatchwear (placeholder).

## Key technical approach
- Segmentation: MediaPipe **multi-class selfie** model `selfie_multiclass_256x256.tflite` (~16 MB, float32). Classes: 0 background, 1 hair, 2 body-skin, 3 face-skin, **4 clothes**, 5 others. Docs: https://ai.google.dev/mediapipe/solutions/vision/image_segmenter
  - Run via `tflite_flutter`, or compare with `face_detection_tflite` (wraps the multiclass model as `SegmentationModel.multiclass`).
  - Pipeline: resize 256×256 → clothes channel → upscale → threshold ~0.5 → largest component, dilate, 2–4 px feather → optional merge body-skin for sleeves / torso crop for "top only".
  - Brush/eraser strokes stored as vectors (undo-friendly), mask re-rasterised.
- Rendering (bottom → top): camera preview (fabric) → shading map (garment luminance / its mean, masked, multiply, strength slider) → portrait PNG with garment alpha cut out.
  - Target: one-pass `FragmentShader`. First spike: `Stack` + `CustomPaint` with `BlendMode.multiply`. Fallback: freeze-frame mode.
  - Pinch/drag the portrait over the camera = sets fabric scale (like the reel).
- Storage: drift + path_provider. Per portrait: original.jpg, mask.png, shading.png, thumb.jpg; looks saved as jpg.

## Architecture
| Feature | Bloc/Cubit | Services |
|---|---|---|
| portraits | PortraitListCubit | PortraitRepository |
| cutout | CutoutBloc (segment, brush, erase, undo/redo) | SegmentationService, MaskProcessor |
| tryon | TryOnBloc (camera, transform, shading, freeze) | CameraService, CompositorShader |
| looks | LooksCubit | LookRepository, ShareService |

Layers: presentation → domain → data. Blocs hold paths/transforms only; pixel work in services/isolates.

Packages: flutter_bloc, equatable, camera, tflite_flutter, image, image_picker, drift, path_provider, share_plus. Pin versions at scaffold time.

## Design
Dark, camera-first UI. Ground `#0F0F0E`, surface `#1C1B19`, border `#2C2B28`, text `#F4F2EE`, muted `#A19D95`, accent chartreuse `#D7F94A` (dark text on it). Fonts: Space Grotesk (display), Inter (body). Phone frame 390×844.
Screens: Portraits (home) → Cutout editor → Live try-on → Look review → Looks gallery. See `design/`.

## Living artifacts (in the Claude app)
- Plan doc: https://claude.ai/artifact/ReCdPNqgFoQJp3Xq2bSTWe
- Design canvas: https://claude.ai/artifact/JM3MekagsJMJy7wMM8ncSq

## Working preferences
- Ask clarifying questions before starting a task; prefer multiple-choice options.
- Keep responses short. Give implementation steps as a markdown checklist instead of full written-out code unless asked.

## Next step
Start at **M0 spikes** in `PLAN.md` — spike 1 (mask quality on real portraits) decides how much the design leans on manual touch-up.
