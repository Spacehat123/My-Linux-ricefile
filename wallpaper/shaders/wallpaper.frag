#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
};

void main() {
    vec2 uv = qt_TexCoord0;
    
    // Aspect-ratio correction centered at (0.5, 0.5)
    float aspect = (resolution.y > 0.0) ? (resolution.x / resolution.y) : 1.0;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    
    // Time harmonic base (time runs [0, 2*PI])
    float t = time;
    
    // Wave components with integer harmonic frequencies (1t, 2t) to ensure seamless 2*PI looping
    float wave1 = sin(p.x * 2.5 + t + sin(p.y * 2.0 - t));
    float wave2 = cos(p.y * 3.0 - t + cos(p.x * 2.0 + 2.0 * t));
    float wave3 = sin((p.x + p.y) * 2.0 + t);
    
    float field = (wave1 + wave2 + wave3) / 3.0; // range [-1.0, 1.0]
    float normField = field * 0.5 + 0.5;         // range [0.0, 1.0]
    
    // Palette matching pranc-shell dark aesthetic:
    // Base obsidian (#0f1017) -> Midnight Violet (#1b1429) -> Oceanic Slate (#0e2030)
    vec3 colBase   = vec3(0.059, 0.063, 0.090); // #0f1017
    vec3 colViolet = vec3(0.106, 0.078, 0.161); // #1b1429
    vec3 colTeal   = vec3(0.055, 0.125, 0.188); // #0e2030
    
    vec3 mixedColor = mix(colBase, colViolet, smoothstep(0.1, 0.7, normField));
    mixedColor = mix(mixedColor, colTeal, smoothstep(0.4, 0.9, normField) * 0.5);
    
    // Subtle radial vignette
    float dist = length(uv - 0.5);
    float vignette = smoothstep(0.9, 0.2, dist);
    vec3 finalRgb = mixedColor * (0.8 + 0.2 * vignette);
    
    // Multiply by qt_Opacity for standard Qt Quick blending
    fragColor = vec4(finalRgb, 1.0) * qt_Opacity;
}
