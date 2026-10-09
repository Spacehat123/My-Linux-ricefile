# Window Stash Pocket & Drag-to-Hide Implementation Report

**Date**: 2026-10-09  
**Target Environment**: Hyprland 0.56.2 on Arch Linux (`pranav-arch`)  
**Workspace**: `/home/pranc/.config/quickshell/cool-shell` & `/home/pranc/.config/hypr/hyprland.lua`  
**Subject**: Removal of persistent peeking tabs and replacement with a contextual "Stash Pocket" (Drop-to-Hide) on the right screen edge.

---

## 1. Summary of Changes

In response to user feedback regarding visual clutter from static border tabs:
1. **Left Peeking Notch Removed**: The left edge is now 100% clean and clear of any tabs or notches.
2. **Right Edge Transformed into "Stash Pocket" (`components/StashPocket.qml`)**:
   - **Idle State (No Stashed Windows)**: Completely invisible (0 visible pixels). Only a 12px sensor strip awaits interaction.
   - **Drag Target Mode**: When dragging a window (`SUPER + LMB`) toward the right edge or hovering the drop sensor, an illuminated magnetic Drop Zone expands into view (`📥 DROP TO STASH`).
   - **Drop Action**: Releasing or clicking inside the drop zone dispatches `hl.dsp.window.move({ workspace = "special:stash", silent = true })`. The window is smoothly absorbed into the stash and hidden from the normal workspace.
   - **Pocket Pill Indicator**: When one or more windows are stashed, a minimal 34px pill sits on the right border displaying the stashed app's icon, count badge, and glowing accent.
   - **Summon / Restore Interaction**:
     - Clicking the pocket pill toggles `special:stash` into view (`hl.dsp.workspace.toggle_special("stash")`).
     - Hovering reveals the stashed app list; clicking any item's restore button (`↩`) returns it immediately to the active workspace.
3. **Hyprland Keybind Integration**:
   - `SUPER + S` configured in `hyprland.lua` to toggle `special:stash`.
   - `SUPER + SHIFT + S` configured to stash the focused window.

---

## 2. Verification Matrix

| Feature | Action / Verification | Status |
| :--- | :--- | :---: |
| **Left Notch Removal** | Inspected left screen edge | **VERIFIED CLEAN** |
| **Drop Target Expansion** | Edge sensor triggered on right screen margin | **EXPANDS TO 160px** |
| **Window Stash Dispatch** | `movetoworkspace special:stash` | **STORED IN SPECIAL:STASH** |
| **Pocket Badge Render** | App icon & count displayed when stashed windows present | **VERIFIED** |
| **Stash Workspace Toggle** | Click pocket pill / `SUPER + S` | **TOGGLES OVERLAY** |
| **Window Restore** | Click restore button (`↩`) | **RESTORES TO ACTIVE WORKSPACE** |
| **Zero Warnings** | `quickshell log -c cool-shell -t 15` | **ZERO WARNINGS** |
