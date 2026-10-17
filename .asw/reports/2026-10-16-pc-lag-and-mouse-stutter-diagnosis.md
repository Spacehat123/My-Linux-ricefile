# PC Lag & Mouse Stutter Diagnostic Investigation Report

**Date**: 2026-10-16  
**Target System**: Acer Aspire A715-42G (AMD Ryzen 5 + NVIDIA GTX 1650 Mobile)  
**Compositor**: Hyprland 0.56.2 (Aquamarine DRM Backend)  
**Primary Display**: `HDMI-A-1` (Samsung Electric Company SAMSUNG 1920x1080@60Hz)  
**Input Device**: Logitech Wireless Mouse (`046d:c534` Nano Receiver)  

---

## 1. The Core Mystery: Why Is It Lagging When CPU & GPU Are "0%"?

- **The Symptom**: The mouse pointer stutters, jerks, and has massive input lag; windows and desktop interactions feel sluggish, yet CPU meters report >90% idle, GPU utilization reports 0%, and RAM has >2.4 GB available.
- **The Explanation**: The bottleneck is **not** computational exhaustion. It is a **DRM Atomic KMS (Kernel Mode Setting) synchronization pipeline stall** combined with **hardware cursor buffer flooding**, **cross-GPU video wallpaper transfer**, and **2.4 GHz radio frequency interference**.

---

## 2. Root Cause Breakdown

### Root Cause 1: Hyprland DRM Hardware Cursor Flooding (Primary Culprit)
- **Mechanism**:
  - In `hyprland.lua`, `cursor:no_hardware_cursors` was not explicitly set, defaulting to `auto` (`int: 2`), which engaged DRM hardware cursor planes (`hardwareCursorsInUse: true`).
  - Aquamarine allocated a 256×256 cursor swapchain of length 2 (`id 151` and `id 152`).
  - For **every single pixel of mouse movement**, Hyprland alternated between buffer 151 and 152, forcing an atomic DRM KMS page-flip commit (`drm: Cursor buffer imported into KMS with id 151/152`).
  - `hyprland.log` recorded **over 20,312 hardware cursor KMS imports** since boot.
  - When an atomic page flip is awaiting on the 60Hz HDMI display (`ERR from aquamarine: drm: Cannot commit when a page-flip is awaiting`), subsequent hardware cursor atomic commits block in the kernel DRM scheduler. This causes the cursor to freeze or drop movement packets while waiting for the next vblank.

### Root Cause 2: Quickshell Live 1080p MP4 Video Wallpaper (NVIDIA $\to$ AMD PCIe Bus Saturation)
- **Mechanism**:
  - Quickshell is actively decoding and looping a 1080p MP4 video wallpaper (`/home/pranc/Pictures/Wallpapers/live/66f5df9a84_peaceful-anime-tree-swing-live-wallpaper-wallsflow-com.mp4`) on `Layer 0 (background)`.
  - Quickshell's rendering backend bound to the **NVIDIA GeForce GTX 1650 dGPU** (PID 91763 holding 644 MiB VRAM), whereas Hyprland and the Samsung HDMI output are physically wired to the **AMD Integrated GPU** (`card1`).
  - Every single frame (60 FPS) must be copied across the PCIe bus via DMA-BUF PRIME synchronization from NVIDIA to AMD, continuously saturating the DRM swapchains behind all windows.

### Root Cause 3: Concurrent GPU/CPU Workloads (FreeCAD + Brave AV1 Video)
- **Mechanism**:
  - `FreeCAD 1.1.4` (PID 112040) is open with an active document, consuming ~31% CPU with active 3D OpenGL rendering.
  - `Brave Browser` (PID 97889) is running a YouTube tutorial with 12 `dav1d` AV1 software video decoding threads + GPU rasterization on AMD iGPU (`renderD128`).
  - System load average is elevated to ~3.0, causing thread scheduler contention.

### Root Cause 4: 2.4 GHz USB RF Interference & Coexistence Contention
- **Mechanism**:
  - The Logitech wireless mouse connects via a 2.4 GHz USB Nano Receiver (`046d:c534`).
  - On the **exact same internal USB root hub (Bus 001)**, the MediaTek Bluetooth controller (`04ca:3802`) is actively streaming high-bitrate audio to a **Rockerz 550** Bluetooth headset.
  - 2.4 GHz Bluetooth streaming directly alongside an unshielded 2.4 GHz wireless mouse dongle creates radio packet collisions, causing dropped mouse polling packets.

### Root Cause 5: Samsung TV HDMI Input Post-Processing Delay
- **Mechanism**:
  - The active monitor is a Samsung TV (`Samsung Electric Company SAMSUNG` on `HDMI-A-1`).
  - If a Samsung TV's HDMI input is not labeled "PC" or set to "Game Mode", its internal video processor applies frame-interpolation and noise reduction, adding **100–150ms of display latency**.

---

## 3. Recommended Remediation Options (Zero-Edit Review)

1. **Disable Hardware Cursors (Instant Fix for Cursor Stutter)**:
   - Setting `cursor:no_hardware_cursors = true` in Hyprland forces the cursor to render via GPU shaders. This stops all 20,000+ atomic KMS commits and gives silky 60fps tracking without DRM stalls.
   - Can be tested instantly in runtime without editing files:
     ```bash
     hyprctl keyword cursor:no_hardware_cursors 1
     ```
2. **Pause or Switch Video Wallpaper**:
   - Switching from a live looping 1080p MP4 video to a static wallpaper in Quickshell completely eliminates the continuous cross-GPU PCIe DMA-BUF transfer.
3. **Samsung TV Game Mode**:
   - Set the Samsung TV picture preset to "Game" or edit the HDMI input source name to "PC" to bypass TV image processing lag.
4. **Wireless Dongle Isolation**:
   - Move the Logitech Nano Receiver to an external USB hub or opposite USB port away from the Bluetooth antenna to prevent 2.4 GHz packet drop.
