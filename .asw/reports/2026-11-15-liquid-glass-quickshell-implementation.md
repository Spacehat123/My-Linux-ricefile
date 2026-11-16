# Architecture & Implementation Report: Apple Liquid Glass for Quickshell (`cool-shell`)

- **Date**: 2026-11-15
- **Author**: Antigravity Chief of Staff & Liquid Glass Systems Architect
- **Target**: Quickshell Desktop Environment (`cool-shell`) & Hyprland Compositor (`hyprland.lua`)
- **Status**: Verified via empirical screenshot capture and optical shader validation

---

## 1. Executive Summary & Problem Diagnosis

The user provided four benchmark images showcasing Apple's visionOS / iOS 18 **Liquid Glass** material:
1. Floating media player & navigation capsule over high-chroma album artwork with deep perimeter refraction, chromatic dispersion, and curved specular rim.
2. Control Center tiles with thick optical bevels refracting an underlying portrait.
3. Lockscreen music player card with frosted glass texture and refractive borders.
4. Floating popup context menu with rounded corners warping a red vintage car along the beveled rim.

### Diagnosis: Why Kitty Failed and Quickshell Succeeded
- **Kitty Limitation**: Kitty is a sandboxed Wayland client. Under Wayland protocol security, client applications cannot access the compositor's framebuffer or read the desktop/windows behind them. Kitty's custom shaders only ever had access to Kitty's own text grid.
- **Quickshell Capability**: Quickshell is the desktop shell itself. It has direct access to the wallpaper texture, layers, and UI hierarchies. Using Qt 6's shader pipeline (`qsb` Qt Shader Baker + `ShaderEffect` + `ShaderEffectSource`), we can run real-time hardware-accelerated optical physics directly on any surface.

---

## 2. Mathematical Physics & Optical Architecture

The Liquid Glass effect is driven by a custom GLSL fragment shader compiled into Qt 6 `.qsb` bytecode:

1. **Signed Distance Field (SDF)**: Evaluates an exact continuous-curvature rounded rectangle:
   $$d(\vec{p}, \vec{b}, r) = \|\max(|\vec{p}| - \vec{b} + r, \vec{0})\| + \min(\max(p_x - b_x + r, p_y - b_y + r), 0) - r$$

2. **Bevel Surface Normal Calculation**:
   Screen-space gradient of the SDF provides the surface slope vector $\vec{grad}$. Across the outer bevel width $W_b \approx 16-24\text{px}$, the normal angles following a circular meniscus:
   $$\theta = \left(\frac{d + W_b}{W_b}\right) \cdot \frac{\pi}{2}$$
   $$\vec{N} = \text{normalize}(\vec{grad} \cdot \sin\theta, \cos\theta)$$

3. **Snell's Law Convex Lens Refraction**:
   Incident rays refract outward at the perimeter, magnifying background pixels and warping high-contrast lines:
   $$\vec{D} = -\vec{N}_{xy} \cdot u_{\text{refraction}}$$

4. **Cauchy / Rayleigh Chromatic Dispersion (Prism Fringing)**:
   The shader samples the background texture at three distinct wavelength coordinates:
   $$\begin{aligned}
   UV_R &= UV + \vec{D} \cdot (1.0 - \delta) \\
   UV_G &= UV + \vec{D} \\
   UV_B &= UV + \vec{D} \cdot (1.0 + \delta)
   \end{aligned}$$

5. **Multi-Tap Frosted Diffusion**:
   In the flat interior of the card, a multi-tap cross-sampling kernel softens the background, while the beveled rim preserves optical clarity.

6. **Directional Key Light & Total Internal Reflection (Fresnel Caustic)**:
   - Key light at $(-0.4, 0.75, 0.55)$ generates a sharp Blinn-Phong specular glint on the top-left chamfer.
   - Grazing shadow darkens the bottom-right edge for 3D grounding.
   - Schlick Fresnel term $F = (1 - \vec{N} \cdot \vec{V})^{3.5}$ creates the thin, glowing caustic rim along the card contour.

---

## 3. Implementation Assets

1. **Shader Source**: `components/shaders/liquid_glass.frag`
2. **Compiled Bytecode**: `components/shaders/liquid_glass.frag.qsb` (compiled with `qsb --qt6 --batchable`)
3. **Reusable Component**: `components/LiquidGlassCard.qml`
4. **Dock Integration**: `panels/BottomBar.qml` floating dock capsule
5. **Hyprland Layer Rule**: `hl.layer_rule` for `pranc-shell` with Dual-Kawase blur
