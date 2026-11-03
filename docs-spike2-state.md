# Spike 2 state (2026-10-29)
- App scaffolded at repo root (Flutter 3.47.5 via fvm, iOS only, org dev.rubenk). Spike becomes the app; variations live on branches (user decision).
- lib/spike/fps_spike_page.dart: A Stack+multiply vs B imageStream->FragmentShader (shaders/composite.frag), fps overlay. Assets from spikes/m0-1-mask/make_spike_assets.py -> assets/spike/ (gitignored, personal photo 08).
- `flutter build ios --no-codesign --debug` succeeds. Not verified on device: camera rotation (shader rotates raw frame 90deg CW), whether BlendMode.multiply blends against the camera Texture (may not).
- User: iOS device + Xcode testing cert ready; spike run starts after usage reset (~1h). Nothing committed.
- Next: user runs `flutter run --release` on device, reports `[spike2]` log lines.

## Update 2026-10-29 (device run, iPhone)
- Shader: 30 fps steady (camera-limited), raster 0.3-0.6 ms, upload ~3-4 ms. iOS BGRA frames arrive upright (720x1280, bpr 2880): no rotation in shader (earlier double-rotation caused streaks).
- Shader shading map now blurred (sigma 10) and darken-only; Stack unchanged.
- Stack fps unmeasured: Flutter "ui fps" does not count camera texture updates.
- Open: Shader detail vs Stack preference after blur; Stack real fps; whether multiply blends against the camera Texture.

## Update 2026-10-29 late (session state, written at context checkpoint)
- Done + on device: Detail slider (Shader), photo import (tflite_flutter, lib/portraits/portrait_pipeline.dart + portrait_store.dart, saved in app documents), Change-photo sheet with instructions. User: "photo is really nicely processed".
- User asks now (in progress): (1) torso cut-off at elbow -> adjustable waist split slider + guide line; plan: keep only cutout_both + portrait.png (opaque original) + split fraction, split computed at render time (shader: alpha=max(cut.a, step); stack: clipped opaque portrait layer). (2) toggle to hide controls (eye button, hide stats too). (3) stock fabrics/patterns for demo: tools/make_fabrics.py -> assets/fabrics/*.jpg (11 tileable swatches); fabric picker Camera vs swatch, tile-scale slider; shader needs uTile uniform + fract(); stack uses ImageShader repeat.
- Constraint from user: ask clarifying Qs before tasks (multiple choice), short answers, checklists over code.
- Nothing committed. Build/install: fvm flutter build ios --release; xcrun devicectl device install app/process launch (phone unlocked); device id 00008110-001579C92184801E.
