# Architectural Blueprint: Apple Liquid Glass Material for Wayland (Hyprland + Quickshell + Kitty)

- **Date**: 2026-11-15
- **Author**: Antigravity Chief of Staff & Liquid Glass Systems Architect
- **Classification**: Production Architecture & Optical Systems Blueprint
- **Target Platform**: Linux Wayland (Hyprland Compositor, Quickshell Qt 6 LayerShell, Kitty GPU Terminal)

---

## Executive Summary & The Optical Paradigm Shift

A simple gaussian or Kawase blur (`backdrop-filter: blur()`) merely removes high-frequency spatial information behind a semi-translucent quad, yielding a lifeless "frosted shower door" effect. In contrast, **Apple Liquid Glass** (pioneered in visionOS and modern macOS/iOS spatial design) is a **physically motivated optical volume**. It treats user interface surfaces not as tinted translucent rectangles, but as physical lenses made of polished optical acrylic or crown glass ($n \approx 1.49 - 1.52$) possessing:
1. **Curvature-induced refraction** that bends and magnifies background photons at surface boundaries.
2. **Wavelength-dependent chromatic dispersion** (Rayleigh/Cauchy prism fringing) at the edges.
3. **Dual-tone directional specular illumination** reflecting a virtual key light on the top/left chamfer and grazing shadow on the bottom/right.
4. **Internal total reflection & caustic edge glow** concentrating luminance 1–2 pixels within the perimeter.
5. **Photonic micro-roughness diffusion** eliminating digital color banding.
6. **Adaptive luminance & chromatic sampling** dynamically shifting the glass between obsidian dark specular and opalescent milky states.
7. **Viscous fluid interaction response** responding to cursor presence, window motion, and system focus.

This blueprint delivers the complete architectural deconstruction, mathematical physics, GLSL shaders, Hyprland compositor configurations, native Kitty terminal integration, and desktop-wide Quickshell application models.

---

## Section 1: Optical Deconstruction & Mathematical Physics of Liquid Glass

```
                      VIRTUAL KEY LIGHT (Top-Left Azimuth 315°, Alt 60°)
                                    \
                                     \  (Specular Bevel)
                                      v
  ============================[ TOP SPECULAR RIM (35% White) ]============================
 ||  +-------------------------------------------------------------------------------+  ||
 ||  | INNER CAUSTIC GLOW (Fresnel Peak F(θ))                                       |  ||
 ||  |                                                                               |  ||
 ||  |   OPTICAL BACKDROP SAMPLE (Dual-Kawase 4-Pass Blur + Vibrancy Boost)          |  ||
 ||  |                                                                               |  ||
 ||  |   UV_Red   = UV + D * (1.0 - δ)   <-- Chromatic Dispersion Prism Fringing     |  ||
 ||  |   UV_Green = UV + D                                                           |  ||
 ||  |   UV_Blue  = UV + D * (1.0 + δ)                                               |  ||
 ||  |                                                                               |  ||
 ||  |   MICRO-ROUGHNESS PHOTONIC GRAIN (2.5% Blue Noise Dithering)                  |  ||
 ||  |                                                                               |  ||
 ||  |   DYNAMIC ADAPTIVE TINT (Obsidian Smoked <---> Milky Opalescent)              |  ||
 ||  +-------------------------------------------------------------------------------+  ||
  ========================[ BOTTOM GRAZING OCCLUSION RIM (30% Dark) ]=====================
```

### 1.1 Base Translucency & Dual-Kawase Downsampled Filtering
Rather than computationally expensive single-pass large-kernel gaussian blurs, the baseline diffusion layer uses **Dual-Kawase filtering**. The composited backdrop buffer is downsampled across 4 mip stages ($1/2 \times 1/2 \to 1/4 \times 1/4 \to 1/8 \times 1/8$) with a 4-tap offset cross, and progressively upsampled with an 8-tap box filter. This yields silky smooth $48\text{px}-60\text{px}$ optical radius at negligible frame-time cost ($<0.4\text{ms}$ on modern GPUs).

### 1.2 Ray-Bending Refraction & Snell's Law via Screen-Space Normals
When light passes from the air ($n_1 = 1.0$) into the glass slab ($n_2 \approx 1.50$), incident rays refract according to Snell's Law:
$$\sin(\theta_2) = \frac{n_1}{n_2} \sin(\theta_1)$$

For a 2D UI window, the flat interior has surface normal $\vec{N} = (0, 0, 1)$, producing zero planar distortion. However, along the rounded outer perimeter and bevel edge (width $W_b \approx 8-16\text{px}$), the surface forms a curved convex meniscus.
Using a Signed Distance Field (SDF) of the rounded rectangle:
$$d(\vec{p}, \vec{b}, r) = \|\max(|\vec{p}| - \vec{b} + r, \vec{0})\| + \min(\max(p_x - b_x + r, p_y - b_y + r), 0) - r$$

For distance $d \in [-W_b, 0]$, the bevel normal $\vec{N}_{xy}$ is:
$$\vec{N}_{xy} = -\nabla d(\vec{p}) \cdot \sin\left(\frac{|d|}{W_b} \cdot \frac{\pi}{2}\right)$$
$$N_z = \sqrt{1.0 - \|\vec{N}_{xy}\|^2}$$

The refractive UV displacement vector $\vec{D}$ applied to the background sampler is:
$$\vec{D} = \vec{N}_{xy} \cdot \left(1.0 - \frac{1.0}{n_{\text{glass}}}\right) \cdot \text{thickness}$$

### 1.3 Chromatic Dispersion / Aberration (Prism Fringing)
Glass has chromatic dispersion: refractive index varies by wavelength $\lambda$ (Cauchy's equation $n(\lambda) = A + B/\lambda^2$). Short-wavelength blue light bends more sharply than long-wavelength red light:
$$n_{\text{blue}} \approx 1.525, \quad n_{\text{green}} \approx 1.500, \quad n_{\text{red}} \approx 1.485$$

The shader splits the backdrop texture fetch across three separated UV coordinates:
$$\begin{aligned}
UV_R &= UV + \vec{D} \cdot (1.0 - \delta) \\
UV_G &= UV + \vec{D} \\
UV_B &= UV + \vec{D} \cdot (1.0 + \delta)
\end{aligned}$$
where $\delta = 0.025$ is the dispersion factor. This creates the optical rainbow fringe along window corners and bevels.

### 1.4 Dual-Tone Edge Illumination & Specular Highlights
A single flat border makes an element look like a 2D cutout. Apple Liquid Glass uses directional 3D lighting:
1. **Top Specular Bevel**: A virtual key light at $\vec{L} = \text{normalize}(-0.4, 0.8, 0.5)$ casts a Blinn-Phong specular highlight:
   $$\vec{H} = \text{normalize}(\vec{L} + \vec{V}), \quad I_{\text{spec}} = (\vec{N} \cdot \vec{H})^\alpha$$
   This yields a crisp, bright white reflection ($35\% - 60\%$ opacity) concentrated on the top and left bevel.
2. **Bottom Grazing Occlusion**: The bottom and right edges face away from the key light, casting an ambient occlusion rim ($20\% - 35\%$ black opacity) that grounds the surface against the wallpaper.
3. **Inner Caustic Rim (Total Internal Reflection)**:
   By Schlick's Fresnel approximation:
   $$F(\theta) = F_0 + (1.0 - F_0)(1.0 - \vec{N} \cdot \vec{V})^5, \quad F_0 = \left(\frac{n_2 - n_1}{n_2 + n_1}\right)^2 \approx 0.04$$
   At grazing angles along the rim ($\vec{N} \cdot \vec{V} \to 0$), reflectivity spikes to $1.0$, producing a glowing internal caustic boundary line $1.5\text{px}$ from the physical edge.

### 1.5 Surface Depth & Photonic Micro-Roughness Grain
Digital blurs suffer from 8-bit banding on dark gradients. Apple injects high-frequency sub-pixel micro-roughness using a procedurally generated blue noise texture blended at $2.5\% - 3.5\%$ with an overlay blend mode:
$$C_{\text{final}} = \text{lerp}(C_{\text{diffuse}}, C_{\text{diffuse}} \cdot (1.0 + (\text{Noise} - 0.5) \cdot 0.06), 0.5)$$
This gives the glass a physical, tactile presence resembling optical glass rather than plastic.

### 1.6 Dynamic Adaptive Tinting & Ambient Luminance Sampling
Liquid Glass is chameleonic. It continuously samples the perceived luminance of the wallpaper or windows beneath it:
$$Y = 0.2126 R + 0.7152 G + 0.0722 B$$
- **Over Dark Backdrops ($Y < 0.35$)**: Shifts into **Obsidian Specular Glass**:
  - Tint: Deep charcoal `#0b0d14` at $55\%$ alpha.
  - Specular bevel: High-contrast pure white ($40\%$).
  - Blur vibrancy: Boosted to $1.25$ to retain underlying color richness.
- **Over Light Backdrops ($Y \ge 0.35$)**: Shifts into **Milky Opalescent Glass**:
  - Tint: Frosted mist `#ffffff` at $35\%$ alpha.
  - Specular bevel: Subdued champagne silver ($20\%$).
  - Edge border: Low-contrast tinted grey (`rgba(0,0,0, 0.15)`).

---

## Section 2: Implementing Apple Liquid Glass for Kitty Terminal under Hyprland

### 2.1 Kitty's Native Configuration (`kitty.conf`)
Kitty executes on the GPU via OpenGL, but on Wayland Kitty delegates compositor effects (blur and backdrop sampling) to Hyprland. To achieve true Apple glass, Kitty provides an unoccluded optical base:

```ini
# ==============================================================================
# KITTY APPLE LIQUID GLASS OPTICAL BASE CONFIGURATION
# ~/.config/kitty/kitty.conf
# ==============================================================================

# 1. Base Glass Tint: Smoked Obsidian with 55% transmittance
# The compositor will sample background light through this translucent base
background #0b0d14
background_opacity 0.55

# 2. Window Breathing Room (Edge Optical Buffer)
# Generous padding prevents terminal glyphs from clipping the refractive bevel
window_padding_width 16 18

# 3. High-Contrast Legible Font Configuration
# Sub-pixel rendering on glass requires bold, crisp foreground typography
font_family      GeistMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        13.5

# 4. Ultra-Crisp Foreground & Accent Palette
# Designed to remain razor-sharp over shifting blurred wallpapers
foreground            #f4f6fc
selection_foreground  #ffffff
selection_background  #483b68
cursor                #e8799e
cursor_text_color     #0b0d14

# Standard ANSI Colors (High-Vibrancy Glass Harmonized)
color0  #141620
color1  #f26b8a
color2  #86d89e
color3  #f5c57a
color4  #7da8ff
color5  #c68aff
color6  #7ee8fa
color7  #d8dce8
color8  #4a4f66
color9  #ff7a98
color10 #98e8ad
color11 #ffd48a
color12 #8eb7ff
color13 #d49eff
color14 #8ef4ff
color15 #ffffff

# 5. Window Frame & Border Handling
hide_window_decorations yes
window_border_width 0
confirm_os_window_close 0
```

### 2.2 Hyprland Compositor Pipeline Configuration (`hyprland.conf`)
Hyprland's `decoration` engine provides the multi-pass Dual-Kawase blur, sub-pixel noise, and 3D elevation shadows that turn Kitty's translucent background into physical frosted glass:

```ini
# ==============================================================================
# HYPRLAND APPLE LIQUID GLASS COMPOSITOR PIPELINE
# ~/.config/hypr/hyprland.conf
# ==============================================================================

decoration {
    # 1. Physical Glass Corner Curvature
    rounding = 18

    # 2. Terminal Transparency Handling
    active_opacity = 1.0
    inactive_opacity = 0.94

    # 3. Optical Blur & Vibrancy Engine (Dual-Kawase Passes)
    blur {
        enabled = true
        size = 12                 # 12px blur radius per pass
        passes = 4                # 4-pass iteration = 48px effective optical diffusion
        new_optimizations = true  # Bypass unneeded frame re-renders
        ignore_opacity = true     # CRITICAL: Forces blur rendering behind Kitty's alpha channel
        xray = false              # Allows blurring windows stacked beneath Kitty (true multi-surface glass)
        noise = 0.038             # Micro-roughness photon diffusion (eliminates banding)
        contrast = 1.18           # Sharpens underlying light sources
        brightness = 1.06         # Compensates for absorption losses inside thick glass
        vibrancy = 0.35           # Saturates refracted wallpaper colors
        vibrancy_darkness = 0.12  # Prevents dark wallpaper areas from washing out
        popups = true
    }

    # 4. Directional Dual-Tone Key-Light Specular Border
    # Simulates top-left 315° directional key light shining across the glass rim
    col.active_border = rgba(ffffff55) rgba(ffffff18) 45deg
    col.inactive_border = rgba(ffffff1c) rgba(00000030) 45deg

    # 5. Spatial Depth Elevation & Caustic Drop-Shadow
    shadow {
        enabled = true
        range = 36
        render_power = 4
        color = rgba(00000066)
        color_inactive = rgba(00000040)
        offset = 0, 10
    }
}

general {
    gaps_in = 8
    gaps_out = 16
    border_size = 1
}

# 6. Dedicated Window Rule for Kitty
windowrulev2 = blur, class:^(kitty)$
windowrulev2 = opacity 1.0 0.94, class:^(kitty)$
```

### 2.3 Custom GLSL Window Shader for Hyprland (`liquid_glass.frag`)
Hyprland supports post-processing screen and window shaders. This custom GLSL fragment shader implements the physical meniscus normal map, chromatic dispersion, and directional specular bevel for all active windows:

```glsl
#version 300 es
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 resolution;
uniform float time;

// Optical Physical Constants
const float IOR_RED   = 1.485;
const float IOR_GREEN = 1.500;
const float IOR_BLUE  = 1.525;
const float BEVEL_WIDTH = 14.0; // Bevel width in pixels
const float CORNER_RADIUS = 18.0;
const vec3  KEY_LIGHT = normalize(vec3(-0.4, 0.8, 0.5));

// 2D Signed Distance Function for Rounded Rectangle
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Sub-pixel pseudo-random hash for micro-roughness dithering
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 pixelCoord = v_texcoord * resolution;
    vec2 center = resolution * 0.5;
    vec2 halfSize = center - vec2(2.0); // 2px edge inset

    // Compute SDF distance from boundary
    float dist = sdRoundedBox(pixelCoord - center, halfSize, CORNER_RADIUS);

    // Default backdrop sample
    vec4 baseColor = texture(tex, v_texcoord);

    if (dist <= 0.0 && dist >= -BEVEL_WIDTH) {
        // We are on the optical curved bevel
        float bevelRatio = clamp(-dist / BEVEL_WIDTH, 0.0, 1.0);
        float angle = bevelRatio * 1.57079632679; // [0, PI/2]

        // Surface normal reconstruction (meniscus lens profile)
        vec2 gradient = vec2(
            sdRoundedBox(pixelCoord + vec2(1.0, 0.0) - center, halfSize, CORNER_RADIUS) -
            sdRoundedBox(pixelCoord - vec2(1.0, 0.0) - center, halfSize, CORNER_RADIUS),
            sdRoundedBox(pixelCoord + vec2(0.0, 1.0) - center, halfSize, CORNER_RADIUS) -
            sdRoundedBox(pixelCoord - vec2(0.0, 1.0) - center, halfSize, CORNER_RADIUS)
        );
        vec2 normXY = normalize(gradient + vec2(1e-5)) * cos(angle);
        float normZ = sin(angle);
        vec3 normal = vec3(normXY, normZ);

        // 1. Ray-Bending Refraction with Chromatic Dispersion
        float dispersionScale = 18.0 / resolution.x;
        vec2 uvR = v_texcoord - normXY * (1.0 - 1.0 / IOR_RED) * dispersionScale;
        vec2 uvG = v_texcoord - normXY * (1.0 - 1.0 / IOR_GREEN) * dispersionScale;
        vec2 uvB = v_texcoord - normXY * (1.0 - 1.0 / IOR_BLUE) * dispersionScale;

        vec3 refracted;
        refracted.r = texture(tex, uvR).r;
        refracted.g = texture(tex, uvG).g;
        refracted.b = texture(tex, uvB).b;

        // 2. Directional Specular Reflection (Blinn-Phong)
        vec3 view = vec3(0.0, 0.0, 1.0);
        vec3 halfVec = normalize(KEY_LIGHT + view);
        float NdotH = max(dot(normal, halfVec), 0.0);
        float specular = pow(NdotH, 24.0) * 0.45;

        // 3. Fresnel Reflectance Rim
        float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - max(dot(normal, view), 0.0), 5.0);
        vec3 rimCaustic = vec3(1.0) * fresnel * 0.35;

        // 4. Directional Grazing Shadow on Bottom-Right
        float shadow = smoothstep(0.2, -0.4, dot(normal.xy, KEY_LIGHT.xy)) * 0.22;

        // Composite Optical Layers
        vec3 finalRGB = refracted + vec3(specular) + rimCaustic - vec3(shadow);

        // Blend onto base window content
        fragColor = vec4(mix(baseColor.rgb, finalRGB, 1.0 - bevelRatio * 0.4), baseColor.a);
    } else {
        // Interior Window Glass Body: Micro-roughness photonic noise dithering
        float noise = (hash12(pixelCoord + time * 0.01) - 0.5) * 0.035;
        fragColor = vec4(baseColor.rgb + vec3(noise), baseColor.a);
    }
}
```

---

## Section 3: Where Else Apple Liquid Glass Can Be Applied

| Desktop Surface | Implementation File | Liquid Glass Role & Effect |
| :--- | :--- | :--- |
| **Top Status Bar & Dynamic Island** | [`panels/TopConvexBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/TopConvexBar.qml) | Organic Bézier morphing drawer with top specular highlight, caustic rim, and internal refraction |
| **Floating Dock / Bottom Bar** | [`panels/BottomBar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/BottomBar.qml) | Floating convex pill with dual-tone directional rim lighting, sub-surface light gradient, and 3D elevation shadow |
| **Left & Right Drawers** | [`panels/LeftSidebar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/LeftSidebar.qml), [`panels/RightSidebar.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/RightSidebar.qml) | Full-height smoked glass side panels with internal micro-roughness dithering and specular right border |
| **Lockscreen** | [`/home/pranc/.config/hypr/hyprlock.conf`](file:///home/pranc/.config/hypr/hyprlock.conf) | 4-pass Dual-Kawase blurred screenshot background with molded glass pill input field and glowing caustic check ring |
| **Volume & Brightness OSDs** | [`island/panels/MediaPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/MediaPanel.qml) | Liquid pill HUD with fluid progress gauges that refract background light through the volume meter |
| **Notification Toasts** | [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml) | Elevated glass toast cards with directional top specular lines, app-derived caustic border tints, and fluid spring dismissals |
| **Workspace Overview & BirdsEye** | [`components/SpatialWorkspaceMap.qml`](file:///home/pranc/.config/quickshell/cool-shell/components/SpatialWorkspaceMap.qml) | 3D glass cards rotating on the Y-axis with edge reflections catching virtual camera lighting |
| **Settings & Control Center** | [`panels/SettingsWindow.qml`](file:///home/pranc/.config/quickshell/cool-shell/panels/SettingsWindow.qml) | Floating spatial glass modal with background darkening scrim and card elevation shelves |
