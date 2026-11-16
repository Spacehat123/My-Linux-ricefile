# Engineering Report: Apple Liquid Glass Physical Refraction Lens Media Player

**Date**: 2026-11-16  
**Topic**: Physical Convex Lens Refraction, Chromatic Dispersion via SVG Filter, and Apple Liquid Glass Material Architecture  
**Target Files**: `widgets/liquid-glass-media-player/index.html`, `widgets/liquid-glass-media-player/liquid-glass.css`, `widgets/liquid-glass-media-player/liquid-glass.js`

---

## 1. Executive Summary

A standard `backdrop-filter: blur(...)` combined with a flat tinted fill merely produces a generic frosted shower door. In contrast, **Apple Liquid Glass** behaves as a physical optical lens with:
1. **Curvature-induced boundary refraction**: Bending background photons inward toward the lens normal along the beveled rim.
2. **Cauchy chromatic dispersion (prism fringing)**: Splitting Red, Green, and Blue wavelengths across distinct displacement scales.
3. **Specular illumination & directional rim reflection**: Catching a virtual 45° key light on the top-left chamfer and grazing shadow on the bottom-right.
4. **WCAG-compliant typography contrast**: Ensuring high-contrast readability without digital gray washing.

This implementation provides the complete, production-grade HTML, CSS, SVG filter, and mathematical displacement map generation engine, verified directly in Chromium.

---

## 2. Optical Architecture & Layer Pipeline

```
  Top-Left Virtual Key Light (45°)
               \
                \
  +==========================[ 1px Specular Gradient Rim (85% White) ]==========================+
  |  Layer 3: Top Chamfer Inner Highlight Glow (1.5px linear-gradient)                           |
  |  -----------------------------------------------------------------------------------------  |
  |  Layer 2: Adaptive Light Color Wash Tint (rgba(255, 255, 255, 0.09) - no flat gray)         |
  |  -----------------------------------------------------------------------------------------  |
  |  Layer 1: Physical Refractive Lens (SVG Filter + Chromatic Dispersion + Kawase Vibrancy)    |
  |           dispR = SourceGraphic * (scale * 1.06)                                            |
  |           dispG = SourceGraphic * (scale * 1.00)                                            |
  |           dispB = SourceGraphic * (scale * 0.94)                                            |
  |           recombined via feComposite additive arithmetic (k2="1", k3="1")                   |
  |  -----------------------------------------------------------------------------------------  |
  |  Layer 4: High-Contrast Content Layer (Razor sharp, concentric radii, WCAG AAA text)        |
  +=============================================================================================+
```

---

## 3. Tunable Variables Guide

| CSS Variable | Default Value | Tunable Range | Effect Description |
| :--- | :--- | :--- | :--- |
| `--refraction-scale` | `48` | `30 – 70` | **Primary lens warp strength**. Higher values increase the convex bending at the perimeter. Lower values make the glass flatter. |
| `--bezel-width` | `14px` | `10px – 20px` | **Width of the refracting border band**. Controls the width of the curved glass chamfer before transitioning to the flat center. |
| `--chromatic-aberration` | `0.06` | `0.02 – 0.12` | **Wavelength dispersion ratio**. Controls the subtle prism color separation (red/cyan/blue fringing) along the refracted edges. |
| `--glass-blur` | `4px` | `2px – 8px` | **Diffusion blur**. Kept light so background details remain recognizable through the lens rather than dissolving into gray soup. |
| `--glass-saturation` | `165%` | `140% – 180%` | **Backdrop vibrancy boost**. Prevents background colors from becoming muted when light passes through the glass. |
| `--glass-tint` | `rgba(255,255,255,0.09)` | `0.05 – 0.18` | **Translucent wash**. Adaptive tint preserving backdrop luminosity. |
| `--specular-opacity` | `0.85` | `0.4 – 1.0` | **Directional key light rim intensity**. Controls the brightness of the top-left highlight and inset bevels. |
| `--light-angle` | `45deg` | `0deg – 360deg` | **Virtual key light direction**. Dynamically shifts with mouse movement for realistic 3D response. |
| `--corner-radius` | `28px` | `16px – 36px` | **Outer continuous squircle corner radius**. Governs concentric inner elements (`innerRadius = outerRadius - padding`). |
| `--shadow-strength` | `1.0` | `0.5 – 1.5` | **Depth elevation multiplier**. Controls soft outer grounding shadows without darkening the panel body. |

---

## 4. Verification Artifacts

- **Dark Mode / Prismatic Scenery Rendering**: [`liquid_glass_card_correct.png`](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/liquid_glass_card_correct.png)
- **Light Mode Sunset Rendering**: [`liquid_glass_light_cropped.png`](file:///home/pranc/.gemini/antigravity-cli/brain/ab1a4395-5e43-4997-afd1-07d69f06f5c4/liquid_glass_light_cropped.png)
- **Component Directory**: [`widgets/liquid-glass-media-player/`](file:///home/pranc/.config/quickshell/cool-shell/widgets/liquid-glass-media-player/)
