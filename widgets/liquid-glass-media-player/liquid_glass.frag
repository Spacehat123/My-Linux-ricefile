#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;              // Widget dimensions in px (width, height)
    float cornerRadius;     // Squircle outer corner radius in px
    float bezelWidth;       // Width of convex bezel band in px
    float refractionScale;  // Lens refraction displacement magnitude
    float ior;              // Index of refraction (~1.4 to 1.6)
    float dispersion;       // Cauchy chromatic dispersion delta (0.02 to 0.12)
    float blurRadius;       // Background diffusion blur in px
    float saturation;       // Vibrancy/chroma multiplier (1.4 to 1.8)
    vec4 tint;              // Adaptive glass tint wash
    float specularOpacity;  // Rim specular intensity (0.5 to 1.0)
    float lightAngle;       // Virtual key light angle in degrees
    float isPressed;        // 1.0 when pressed, 0.0 normal
    float isHovered;        // 1.0 when hovered
    vec2 mousePos;          // Cursor coordinate for interactive tilt
    float debugMode;        // 0 = normal glass, 1 = normal vectors, 2 = UV displacement
};

layout(binding = 1) uniform sampler2D backdrop;

void main() {
    // Center-origin pixel coordinates
    vec2 halfSize = size * 0.5;
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * size;

    // Signed Distance Field (SDF) of rounded box
    float cr = max(1.0, min(cornerRadius, min(halfSize.x, halfSize.y)));
    vec2 b = halfSize - vec2(cr);
    vec2 q = abs(p) - b;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - cr;

    // Discard outer fragments with sub-pixel antialiasing
    if (d > 1.5) {
        fragColor = vec4(0.0);
        return;
    }
    float alpha = smoothstep(1.0, -0.5, d) * qt_Opacity;

    // Distance from outer perimeter inward
    float distFromEdge = max(0.0, -d);

    // 2D Outward normal vector
    vec2 n2d = vec2(0.0);
    if (q.x > 0.0 && q.y > 0.0) {
        n2d = normalize(q) * sign(p);
    } else if (q.x > q.y) {
        n2d = vec2(sign(p.x), 0.0);
    } else {
        n2d = vec2(0.0, sign(p.y));
    }

    // Convex Bezel Height Profile:
    // h(t) = sqrt(1 - (1 - t)^2), steep at edge (t=0), flat at inner rim (t=1)
    float bWidth = max(2.0, bezelWidth);
    float t = clamp(distFromEdge / bWidth, 0.0, 1.0);
    
    // Height slope derivative: dh/dt = (1 - t) / sqrt(1 - (1 - t)^2)
    float denom = max(0.08, sqrt(max(0.001, 1.0 - (1.0 - t) * (1.0 - t))));
    float slope = (t < 1.0) ? ((1.0 - t) / denom) : 0.0;

    // Construct 3D Surface Normal vector
    // At flat center (t >= 1.0): N = (0, 0, 1)
    vec3 N = normalize(vec3(-n2d * slope * (bWidth / 24.0), 1.0));

    // Debug Modes
    if (debugMode > 2.5) {
        // Mode 3: Show Raw Captured Backdrop Texture (unrefracted, untinted)
        fragColor = texture(backdrop, qt_TexCoord0) * alpha;
        return;
    } else if (debugMode > 1.5) {
        // Mode 2: Show Refraction UV Displacements as colors
        vec2 dispVec = -n2d * slope * (refractionScale / size);
        fragColor = vec4(dispVec * 15.0 + vec2(0.5), 0.5, alpha);
        return;
    } else if (debugMode > 0.5) {
        // Mode 1: Show 3D Surface Normal vectors as RGB colors
        fragColor = vec4(N * 0.5 + vec3(0.5), alpha);
        return;
    }

    // Snell's Law Refraction Ray Calculation:
    // Incident view ray V = (0, 0, -1) looking down into the surface
    vec3 V = vec3(0.0, 0.0, -1.0);
    float safeIor = max(1.1, ior);
    vec3 R = refract(V, N, 1.0 / safeIor);

    // Base UV displacement offset (pointing inward, zero at center)
    vec2 uvOffset = R.xy * (refractionScale / size);

    // Subtle 1.03x interior lens magnification
    vec2 magOffset = -(p / halfSize) * 0.018 * (1.0 - t * 0.5);
    uvOffset += magOffset;

    // Cauchy Chromatic Dispersion:
    // Sample Red, Green, and Blue at slightly separated refraction scales
    float disp = max(0.0, dispersion);
    vec2 uvR = clamp(qt_TexCoord0 + uvOffset * (1.0 + disp), vec2(0.002), vec2(0.998));
    vec2 uvG = clamp(qt_TexCoord0 + uvOffset * 1.0,          vec2(0.002), vec2(0.998));
    vec2 uvB = clamp(qt_TexCoord0 + uvOffset * (1.0 - disp), vec2(0.002), vec2(0.998));

    // Multi-tap light diffusion blur (2 to 8 px equivalent)
    vec2 blurStep = (max(0.5, blurRadius) / size);
    vec3 color;
    
    // 5-tap kernel for Red channel
    float colR = (texture(backdrop, uvR).r * 0.36 +
                  texture(backdrop, uvR + vec2( blurStep.x,  blurStep.y)).r * 0.16 +
                  texture(backdrop, uvR + vec2(-blurStep.x,  blurStep.y)).r * 0.16 +
                  texture(backdrop, uvR + vec2( blurStep.x, -blurStep.y)).r * 0.16 +
                  texture(backdrop, uvR + vec2(-blurStep.x, -blurStep.y)).r * 0.16);

    // 5-tap kernel for Green channel
    float colG = (texture(backdrop, uvG).g * 0.36 +
                  texture(backdrop, uvG + vec2( blurStep.x,  blurStep.y)).g * 0.16 +
                  texture(backdrop, uvG + vec2(-blurStep.x,  blurStep.y)).g * 0.16 +
                  texture(backdrop, uvG + vec2( blurStep.x, -blurStep.y)).g * 0.16 +
                  texture(backdrop, uvG + vec2(-blurStep.x, -blurStep.y)).g * 0.16);

    // 5-tap kernel for Blue channel
    float colB = (texture(backdrop, uvB).b * 0.36 +
                  texture(backdrop, uvB + vec2( blurStep.x,  blurStep.y)).b * 0.16 +
                  texture(backdrop, uvB + vec2(-blurStep.x,  blurStep.y)).b * 0.16 +
                  texture(backdrop, uvB + vec2( blurStep.x, -blurStep.y)).b * 0.16 +
                  texture(backdrop, uvB + vec2(-blurStep.x, -blurStep.y)).b * 0.16);

    color = vec3(colR, colG, colB);

    // Saturation and Vibrancy boost
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, max(1.0, saturation));

    // Slight brightness lift
    color *= 1.05;

    // Adaptive Light Color Wash Tint
    color = mix(color, tint.rgb, tint.a);

    // Specular Lighting & Directional Rim Highlights (45° virtual key light)
    float rad = radians(lightAngle);
    vec3 lightDir = normalize(vec3(-cos(rad), sin(rad), 0.72));

    // Blinn-Phong highlight catching the bevel
    vec3 H = normalize(lightDir + vec3(0.0, 0.0, 1.0));
    float NdotH = max(dot(N, H), 0.0);
    float spec = pow(NdotH, 28.0) * (1.0 - t); // Concentrated on the curved bezel

    // Schlick Fresnel edge brightening
    float fresnel = pow(1.0 - max(dot(N, vec3(0.0, 0.0, 1.0)), 0.0), 3.2);

    // 1px sharp outer rim highlight (brightest at top-left and bottom-right)
    float outer1px = 1.0 - smoothstep(0.0, 1.5, distFromEdge);
    float rimDirectional = (0.55 + 0.45 * max(dot(n2d, -lightDir.xy), 0.0));
    float sharpRim = outer1px * rimDirectional;

    // Faint inner glow along top edge bevel
    float topEdgeGlow = smoothstep(2.0, 0.0, abs(p.y - (-halfSize.y + 1.2))) * (1.0 - smoothstep(0.0, halfSize.x - 24.0, abs(p.x)));

    // Total Specular & Rim response
    float totalSpec = (spec * 0.85 + fresnel * 0.40 + sharpRim * 0.90 + topEdgeGlow * 0.65) * specularOpacity;
    if (isPressed > 0.5) totalSpec *= 1.30;
    if (isHovered > 0.5) totalSpec *= 1.15;

    color += vec3(totalSpec);

    fragColor = vec4(color * alpha, alpha);
}
