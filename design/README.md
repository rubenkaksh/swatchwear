# Design reference

The live, editable canvas is at https://claude.ai/artifact/JM3MekagsJMJy7wMM8ncSq. Use the canvas as the visual source of truth.

`mockups/*.dc.html` are the canvas's source files. They need the canvas runtime to render, so treat them as a spec: layout, spacing, colors, copy and icons are all there inline.

| File | Screen | Flutter route (suggested) |
|---|---|---|
| Main.dc.html | Portraits (home) | /portraits |
| Cutout.dc.html | Cutout editor | /portraits/:id/cutout |
| TryOn.dc.html | Live try-on (interactive in canvas: tap portrait cycles fabric, shading slider works) | /portraits/:id/tryon |
| Review.dc.html | Look review | /portraits/:id/review |
| Looks.dc.html | Looks gallery + compare | /looks |
| Figure.dc.html | Stylised portrait placeholder (not an app screen) | — |

Tokens: bg #0F0F0E · surface #1C1B19 · border #2C2B28 · text #F4F2EE · muted #A19D95 · accent #D7F94A · radii 14/18/22/28 · touch targets ≥44 px · Space Grotesk + Inter.

Additional tokens (added in polish): selected tint #262B12 · outline #4A4843 · live/record #FF5A4E · overlay rgba(15,15,14,0.72–0.86). Radii in use: 12 (thumbs), 14 (inputs), 16 (tool buttons), 18/22 (cards, canvases), pill (chips/buttons, half-height), 28 (nav/panel). Top inset 56 on every screen. Touch targets: 44 px minimum, 48 px for icon buttons (Android 48 dp).
