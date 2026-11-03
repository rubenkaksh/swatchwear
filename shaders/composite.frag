#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uStrength;
uniform vec2 uCamScale;  // cover-fit visible fraction of the (portrait-upright) camera frame
uniform vec2 uCutScale;  // same for the portrait
uniform float uDetail;   // 0 = blurred shading (flat fabric), 1 = sharp shading (garment folds, seams)
uniform float uTile;     // 0 = camera frame; >0 = swatch repeated this many times across the screen width
uniform float uSplit;    // waist line, fraction of portrait height
uniform float uRegion;   // 0 both, 1 torso only, 2 legs only
uniform sampler2D uCamera;  // camera frame (upright on iOS) or fabric swatch
uniform sampler2D uShade;
uniform sampler2D uCut;     // portrait RGBA, garment alpha = 0
uniform sampler2D uShadeSharp;
uniform sampler2D uPortrait;  // opaque original, shown where the garment part is excluded

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 pu = (uv - 0.5) * uCutScale + 0.5;
  vec4 cut = texture(uCut, pu);
  float ratio = mix(texture(uShade, pu).r, texture(uShadeSharp, pu).r, uDetail);
  vec3 fabric;
  if (uTile > 0.0) {
    fabric = texture(uCamera, fract(vec2(uv.x, uv.y * uSize.y / uSize.x) * uTile)).rgb;
  } else {
    vec2 cam = (uv - 0.5) * uCamScale + 0.5;
    fabric = texture(uCamera, cam).rgb;
  }
  vec3 worn = fabric * mix(1.0, ratio, uStrength);
  vec3 base = mix(worn, cut.rgb, cut.a);
  float below = smoothstep(uSplit - 0.004, uSplit + 0.004, pu.y);
  float keep = uRegion < 0.5 ? 1.0 : (uRegion < 1.5 ? 1.0 - below : below);
  fragColor = vec4(mix(base, texture(uPortrait, pu).rgb, 1.0 - keep), 1.0);
}
