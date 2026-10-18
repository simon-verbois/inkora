#include <flutter/runtime_effect.glsl>

// Impeller supplies the viewport texture/size. Used only for the PDF viewport;
// raster pages and covers draw directly without an intermediate surface.
uniform vec2 u_size;
uniform float u_strength;
uniform sampler2D u_image;
out vec4 fragColor;

vec4 sampleImage(vec2 uv) {
  return texture(u_image, clamp(uv, .5 / u_size, 1.0 - .5 / u_size));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  #ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
  #endif
  vec2 stepSize = 1.0 / u_size;
  vec4 c = sampleImage(uv);
  vec3 n = sampleImage(uv + vec2(0.0, -stepSize.y)).rgb;
  vec3 s = sampleImage(uv + vec2(0.0, stepSize.y)).rgb;
  vec3 w = sampleImage(uv + vec2(-stepSize.x, 0.0)).rgb;
  vec3 e = sampleImage(uv + vec2(stepSize.x, 0.0)).rgb;
  vec3 low = min(c.rgb, min(min(n, s), min(w, e)));
  vec3 high = max(c.rgb, max(max(n, s), max(w, e)));
  vec3 detail = clamp((4.0 * c.rgb - n - s - w - e) * u_strength, -.12, .12);
  fragColor = vec4(clamp(c.rgb + detail, low, high), c.a);
}
