// Subtle bloom/glow for Ghostty — cursor-agnostic (works with cursor-style = bar).
// ShaderToy-compatible: samples the rendered terminal (iChannel0) and adds a soft
// glow around bright pixels. Static (no iTime), so pair with
// `custom-shader-animation = false` to avoid continuous GPU redraws.
// Tune the constants below; set BLOOM_STRENGTH = 0.0 to effectively disable.
//
// Alpha passes through (and scales the glow, in case the texture is
// premultiplied) so background-opacity and background-blur keep working.
// The glow also fades out in bright neighborhoods: a light theme's background
// (Catppuccin Latte is ~0.94) otherwise clears THRESHOLD everywhere and the
// whole window washes out toward white.

const float BLOOM_STRENGTH = 0.55;  // 0 = off, ~1 = heavy
const float THRESHOLD      = 0.60;  // only pixels brighter than this bleed
const float RADIUS         = 1.6;   // sample spread, in pixels
const vec2  LIGHT_FADE     = vec2(0.35, 0.60); // avg luminance where glow fades out

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(iChannel0, uv);

    vec2 px = 1.0 / iResolution.xy;
    vec3 bloom = vec3(0.0);
    float lum = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec3 s = texture(iChannel0, uv + vec2(float(x), float(y)) * px * RADIUS).rgb;
            bloom += max(s - THRESHOLD, 0.0);
            lum += dot(s, vec3(0.2126, 0.7152, 0.0722));
        }
    }
    bloom /= 25.0;
    lum /= 25.0;
    bloom *= 1.0 - smoothstep(LIGHT_FADE.x, LIGHT_FADE.y, lum);

    fragColor = vec4(src.rgb + bloom * BLOOM_STRENGTH * src.a, src.a);
}
