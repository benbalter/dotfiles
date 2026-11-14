// Subtle bloom/glow for Ghostty — cursor-agnostic (works with cursor-style = bar).
// ShaderToy-compatible: samples the rendered terminal (iChannel0) and adds a soft
// Gaussian glow around text that's brighter than the background. Static (no
// iTime), so pair with `custom-shader-animation = false` to avoid continuous GPU
// redraws. Tune the constants below; set BLOOM_STRENGTH = 0.0 to disable.
//
// Brightness is measured against iBackgroundColor rather than an absolute
// threshold: thin glyph strokes only cover a few samples, so an absolute cutoff
// left the glow invisible on dark themes, while a light theme's background
// (Catppuccin Latte) cleared it everywhere and washed out. The glow is skipped
// entirely on light backgrounds. Alpha passes through (and scales the glow, in
// case the texture is premultiplied) so background-opacity and blur still work.

const float BLOOM_STRENGTH = 1.5;   // 0 = off, ~2.5 = heavy
const float MARGIN         = 0.25;  // how much brighter than the background a pixel must be to glow
const float STEP           = 2.0;   // sample spacing, in pixels (halo reaches ~3x this)
const float SIGMA          = 1.5;   // Gaussian falloff, in samples

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(iChannel0, uv);

    float bgLuma = luma(iBackgroundColor);
    float dark = 1.0 - smoothstep(0.4, 0.6, bgLuma);
    if (dark <= 0.0) {
        fragColor = src;
        return;
    }

    vec2 px = STEP / iResolution.xy;
    vec3 bloom = vec3(0.0);
    float wsum = 0.0;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            float w = exp(-float(x * x + y * y) / (2.0 * SIGMA * SIGMA));
            vec3 s = texture(iChannel0, uv + vec2(float(x), float(y)) * px).rgb;
            bloom += s * max(luma(s) - bgLuma - MARGIN, 0.0) * w;
            wsum += w;
        }
    }
    bloom /= wsum;

    fragColor = vec4(src.rgb + bloom * BLOOM_STRENGTH * dark * src.a, src.a);
}
