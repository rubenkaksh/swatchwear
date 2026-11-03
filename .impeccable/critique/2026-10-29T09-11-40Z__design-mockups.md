---
target: design mockups
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/rubenk/projects/sandbox/workspaces/swatchwear/design/mockups"
timestamp: 2026-10-29T09-11-40Z
slug: design-mockups
---
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
