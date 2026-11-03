# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Fashion-curious social-media users (confirmed). They have seen the "print your portrait, cut out the shirt, hold it over fabric" trend and want to do it on a phone: at home, in a fabric shop, or wherever a fabric catches their eye. Phone in hand, often one-handed, usually aiming the camera at something while looking at the screen. They want a shareable image fast, not a tool to learn.

## Product Purpose

Swatchwear (working name: Swatch) turns that trend into software. The user cuts the clothing out of a portrait photo, then sees the live camera feed, pointed at any fabric, through that cutout, with the original garment's folds and shadows blended on top so the fabric looks worn. Success: a believable, shareable look in a few taps, with no accounts, no backend, no network.

## Positioning

The camera is the fabric library. Nothing is uploaded, browsed or generated: the material is whatever the phone is pointed at right now, in the user's own portrait. A fabric-catalogue or generative try-on app cannot truthfully copy that.

## Operating Context

- Personal MVP, fully offline, iOS and Android, no accounts or backend.
- Flow: add portrait, auto cutout (about 1 s, on device), refine with brush/eraser, live try-on, capture, save to Looks, share.
- Segmentation runs on device: MediaPipe multi-class selfie model (`selfie_multiclass_256x256.tflite`, ~16 MB), clothes class 4.
- Realism is flat fabric plus a shading blend (multiply / soft-light of the garment luminance). No generative AI.

## Capabilities and Constraints

- Fabric source is the live camera only. No fabric library, no snapped fabric photos in v1.
- Cutout is auto segmentation plus manual brush/eraser touch-up; strokes stored as vectors (undo-friendly). Region modes: top only / top + sleeves / full outfit.
- State management: Bloc (flutter_bloc), feature-first folders. Storage: drift + path_provider.
- Flutter, one codebase for both OSes. Screens: Portraits (home), Cutout editor, Live try-on, Look review, Looks gallery.
- Camera frame rate (target 24 fps or better on a mid-range phone) and mask quality are unproven; M0 spikes decide the fallbacks (freeze-frame mode, manual brush as primary).
- Undecided: final app name, light-mode appearance, tablet layouts.

## Brand Commitments

Working name Swatch / Swatchwear (placeholder). Dark, camera-first UI already specified in `design/` and treated as the incumbent direction: ground #0F0F0E, accent chartreuse #D7F94A, Space Grotesk and Inter. The user confirmed these as decisions made, not as open questions.

## Evidence on Hand

- Design canvas: https://claude.ai/artifact/JM3MekagsJMJy7wMM8ncSq ; source files in `design/mockups/*.dc.html`.
- `PLAN.md` (flow, data model, risks, milestones) and `CLAUDE.md` (decisions).
- Absent: real test portraits, real-device performance numbers, user research. Do not invent any.

## Product Principles

1. The camera feed is the hero; chrome stays out of its way.
2. Few taps from photo to a shareable look.
3. Honest realism: shading is a blend, not magic. Show the limits (busy or dark tops) instead of hiding them.
4. Everything works offline and on device; the user's photos never leave the phone unless they share.
5. Manual control backs up automation: when the cutout is wrong, brush and eraser must be quick.

## Accessibility & Inclusion

Touch targets of at least 44 pt (iOS) / 48 dp (Android). Text must scale with system settings. Dark surfaces over live camera need verified contrast. Not otherwise specified.
