// Subtle bloom/glow for Ghostty — cursor-agnostic (works with cursor-style = bar).
// ShaderToy-compatible: samples the rendered terminal (iChannel0) and adds a soft
// glow around bright pixels. Static (no iTime), so pair with
// `custom-shader-animation = false` to avoid continuous GPU redraws.
// Tune the three constants below; set BLOOM_STRENGTH = 0.0 to effectively disable.

const float BLOOM_STRENGTH = 0.55;  // 0 = off, ~1 = heavy
const float THRESHOLD      = 0.60;  // only pixels brighter than this bleed
const float RADIUS         = 1.6;   // sample spread, in pixels

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 base = texture(iChannel0, uv).rgb;

    vec2 px = 1.0 / iResolution.xy;
    vec3 bloom = vec3(0.0);
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec3 s = texture(iChannel0, uv + vec2(float(x), float(y)) * px * RADIUS).rgb;
            bloom += max(s - THRESHOLD, 0.0);
        }
    }
    bloom /= 25.0;

    fragColor = vec4(base + bloom * BLOOM_STRENGTH, 1.0);
}
