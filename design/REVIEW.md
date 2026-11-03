# Design review — audit + critique (2026-10-29)

Target: `design/mockups/{Main,Cutout,TryOn,Review,Looks}.dc.html` (source read; the canvas runtime `support.js` is not in the repo, so nothing was rendered).
Platform: adaptive (Flutter, iOS + Android). Method: design review only, detector not applicable (native platform).

## Audit (technical, from source)

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 2 | Pinch/drag is the only way to scale or move the portrait; chips/buttons at 36–40 px; selection shown by border colour only |
| 2 | Performance | 3 | Not testable on mockups; Home grid is a fixed non-scrolling layout that will need a lazy grid with `thumb.jpg` |
| 3 | Appearance & Theming | 3 | Consistent palette; 4 colours and 6 radii are outside the token list; dark-only is deliberate but must force light status-bar icons |
| 4 | Platform Conformance | 2 | Custom pill nav, hard-coded 56/64 px top and 34 px bottom insets, web-style gear/arrow icons, no sheets or permission flows |
| 5 | Adaptivity | 1 | Everything is absolutely or fixed-height sized to 390×844; Cutout and Review overflow on a 667 pt phone; no landscape or tablet answer |
| **Total** | | **11/20** | **Acceptable, significant work needed** |

### Platform conformance verdict
Passes as a coherent custom brand over a standard structure (tab-like nav, push screens, full-screen camera). It reads as a web mock, not yet as a native app: insets are pixel constants, the back control is a custom circle, no OS sheets for add-portrait / delete / share, no permission states.

### Findings
- **[P1] Home cannot scroll; Add tile is last.** `Main.dc.html` grid is `flex:1` inside `overflow:hidden`. Past ~6 portraits the Add tile and later portraits are unreachable. Fix: scrollable grid, Add as first tile. → `layout`
- **[P1] Fixed-size screens break below ~760 pt height.** Cutout canvas 430 px, Review image 420 px, TryOn absolute `top:150/520`. On 667 pt the controls overflow and TryOn's portrait overlaps the control panel. Fix: canvas takes the remaining height (`Expanded`, min height), TryOn positions relative to the safe area. → `adapt`
- **[P1] No non-gesture way to scale or move the portrait; no reset.** Pinch/drag only. Fix: add a "Fit" (reset) control and an optional size stepper. → `harden`
- **[P1] Touch targets under 44/48.** Region chips 40, Looks Compare 40, tag chips 36, Add-tag 36. → `layout`
- **[P1] No path back into the cutout for an existing portrait.** Tapping a portrait goes to TryOn, TryOn has no "Edit cutout". → `harden`
- **[P2] Selection is colour-only** in Looks (lime vs #2C2B28 border). Add a check badge. → `harden`
- **[P2] Toggle state not shown** for Torch and Freeze (no pressed look). → `harden`
- **[P2] Token drift.** Undocumented: #262B12, #4A4843, #C9C5BD, #FF5A4E. Radii used: 6, 12, 14, 16, 18, 20, 22, 27, 28 vs documented 14/18/22/28. Top padding 64 on Main/Looks, 56 elsewhere. → `extract`
- **[P2] Icon drift and misleading icons.** Stroke 1.8/2/2.2 mixed; "Settings" is a sun-burst; Settings has no screen. In Flutter map to Cupertino/Material icons. → `polish`
- **[P2] Fonts in px.** Flutter build must use `TextScaler`; verify layouts at 130 % and 200 %. → `adapt`
- **[P3] Unselected control boundary (#2C2B28 on #0F0F0E) is about 1.3:1.** Text carries the meaning, so tolerable; consider #3A3935 for outlines on interactive controls.

### Positive findings
Text contrast is strong (#F4F2EE on #0F0F0E about 17:1, muted #A19D95 about 7:1, dark on lime about 16:1). Icon buttons are labelled. The capture button, shading slider and primary actions sit in the thumb zone. Selected/unselected chips differ by fill and weight, not colour alone (except Looks).

## Critique (UX)

Method: design review only (detector not applicable, native platform).

### Design specificity verdict
Authored for this product: the paper-print frame tilted over live fabric (white border, -3° rotation, drop shadow) is the trend, drawn. The chartreuse shutter on a camera-first dark UI is distinctive and earns its place. Home, Review and Looks are competent but interchangeable; only TryOn has a point of view.

### Design Health Score (10 of 10 applicable)

| # | Heuristic | Score | Key issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | No "cutting out…" progress, no camera-permission state, no freeze indicator |
| 2 | Match System / Real World | 3 | "Cut out" label over region chips is ambiguous; "96% of top" is an invented metric |
| 3 | User Control and Freedom | 2 | Undo exists; no discard-edits guard, no way to re-enter cutout, "Re-detect" may wipe strokes |
| 4 | Consistency and Standards | 3 | Strong shared header/chip system; top padding and radii drift |
| 5 | Error Prevention | 2 | Re-detect and delete are unguarded (delete does not exist yet) |
| 6 | Recognition Rather Than Recall | 3 | Labelled controls; hint pill never retires |
| 7 | Flexibility and Efficiency | 2 | Review demands name + tags before saving; no quick share |
| 8 | Aesthetic and Minimalist Design | 3 | TryOn is clean; small uppercase section labels repeat 5 times |
| 9 | Error Recovery | 1 | No error states anywhere (no clothing found, bad light, camera denied) |
| 10 | Help and Documentation | 2 | One hint pill; no first-run guidance for the portrait photo |
| **Total** | | **23/40** | **Acceptable** |

### Priority issues
1. **[P1] The error and empty states are the product, and they are missing.** Camera permission denied, no clothing detected, zero portraits, zero looks, model still loading. Fix: design these five states. → `harden`, `onboard`
2. **[P1] Social users cannot share fast.** Share is a small top-right icon; Save needs a name and tags first. Fix: default name "Look 7" (the app cannot know the fabric, so "Polka slip dress" is fiction), Share as a secondary button next to Save. → `clarify`, `layout`
3. **[P1] No route back to the cutout; add-portrait skips source choice.** Fix: "Edit cutout" in TryOn, source sheet (Camera / Photos) from the Add tile, and a short processing state. → `harden`, `onboard`
4. **[P2] Fake precision.** "Auto-detected · 96% of top" claims a measure the model does not produce. Fix: "Auto-detected" plus a hint to check edges. Spike 1 decides what to say. → `clarify`
5. **[P2] Looks screen is unclear.** "Me / 6 looks" implies a portrait filter with no switcher; items are not tappable; compare state has no exit. → `shape`

### Persona red flags
- **Casey (distracted mobile):** back/close controls top-left are out of thumb reach (fine for rare use); hint pill covers the fabric; state lost if the OS kills the camera screen.
- **Jordan (first-timer):** "Cut out" chips, "Re-detect", and shading are unexplained; first screen never says to use a plain top.
- **Sam (accessibility):** cannot scale the portrait without pinch; Looks selection by colour only; fixed px type.
- **Trend-follower "Maya" (project):** wants a post-ready image in under a minute; faces name+tags form, then top-right share icon; no 9:16 export affordance.

### Questions
- What if Review opened straight on the share sheet, with Save as the quiet option?
- Does the portrait frame need a visible fabric-scale readout ("2.4×") so the same fabric is reproducible?
