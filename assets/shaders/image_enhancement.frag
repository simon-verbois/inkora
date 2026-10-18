#include <flutter/runtime_effect.glsl>

uniform vec2 u_targetSize;
uniform vec2 u_imageSize;
uniform vec4 u_source;
uniform float u_strength;
uniform sampler2D u_image;
out vec4 fragColor;

vec4 sampleImage(vec2 uv) {
  return texture(u_image, clamp(uv, .5 / u_imageSize, 1.0 - .5 / u_imageSize));
}

vec3 straight(vec4 value) {
  return value.a > .0001 ? value.rgb / value.a : vec3(0.0);
}

void main() {
  vec2 uv = (u_source.xy + FlutterFragCoord().xy / u_targetSize * u_source.zw) / u_imageSize;
  vec2 stepSize = 1.0 / u_imageSize;
  vec4 center = sampleImage(uv);
  vec3 c = straight(center);
  vec3 n = straight(sampleImage(uv + vec2(0.0, -stepSize.y)));
  vec3 s = straight(sampleImage(uv + vec2(0.0, stepSize.y)));
  vec3 w = straight(sampleImage(uv + vec2(-stepSize.x, 0.0)));
  vec3 e = straight(sampleImage(uv + vec2(stepSize.x, 0.0)));
  // Limit enhancement to the local color range: no bright/dark ringing beyond
  // the source extrema, and preserve the center alpha at transparent edges.
  vec3 low = min(c, min(min(n, s), min(w, e)));
  vec3 high = max(c, max(max(n, s), max(w, e)));
  vec3 detail = clamp((4.0 * c - n - s - w - e) * u_strength, -.12, .12);
  fragColor = vec4(clamp(c + detail, low, high) * center.a, center.a);
}
