# Remediation Report: Ambient Telemetry Cleanup & Dynamic Idle Mode Fix

**Date**: 2026-11-17  
**Status**: VERIFIED & RESOLVED  
**Issue Description**: 
1. Residual ambient telemetry elements (Study Sessions calendar heatmap, corner tactical brackets, and bottom-left telemetry box) remained visible alongside the newly added Weather & Clock Slate.
2. Ambient "Dynamic" mode failed to operate as intended, staying stuck as always-on or always-off.

---

## 1. Root Cause Analysis

1. **Residual Elements**:
   - In [desktop/AmbientLayer.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/AmbientLayer.qml), `AmbientCornerBrackets.qml`, `AmbientTelemetry.qml`, and `StudyContributionHeatmap.qml` were still instantiated inside `hudContainer`, cluttering the background perimeter and bottom edge.
2. **Dynamic Mode Failure**:
   - `AmbientLayer.qml` had `readonly property bool active: (alwaysOn || idle || emptyWorkspace) && enabled`.
   - `emptyWorkspace: (currentSurfaceCount === 0)` was injected from `shell.qml`.
   - On an empty workspace, `emptyWorkspace` remained `true` even when the user was actively using the machine (`idle: false`).
   - Consequently, in Dynamic Mode (`enabled: true, alwaysOn: false`), `active` evaluated to `true`, forcing the ambient HUD to remain continuously visible rather than waiting for user idle timeout.

---

## 2. Changes Made

1. **Complete Clutter Elimination** in [desktop/AmbientLayer.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/AmbientLayer.qml):
   - Removed `AmbientCornerBrackets` (tactical corner lines, system status labels).
   - Removed `AmbientTelemetry` (bottom-left telemetry box).
   - Removed `StudyContributionHeatmap` (bottom-center study sessions heatmap).
   - Preserved **strictly** [desktop/DesktopAmbientSlate.qml](file:///home/pranc/.config/quickshell/cool-shell/desktop/DesktopAmbientSlate.qml) as the single focal ambient element.
2. **Restored Dynamic Mode Contract**:
   - Reverted `AmbientLayer.active` strictly to `(alwaysOn || idle) && enabled`.
   - Removed `emptyWorkspace` override from [shell.qml](file:///home/pranc/.config/quickshell/cool-shell/shell.qml).
   - Re-verified 3 clean states:
     - **Dynamic (`ambientEnabled: true, alwaysOn: false`)**: Invisible during active usage; fades in after 120s idle timeout; fades out instantly upon user input.
     - **Always On (`ambientEnabled: true, alwaysOn: true`)**: Continually displayed.
     - **Disabled (`ambientEnabled: false, alwaysOn: false`)**: Completely suppressed.
3. **Instant Feedback in Control Center**:
   - Added transient notification toasts in [components/ControlCenter.qml](file:///home/pranc/.config/quickshell/cool-shell/components/ControlCenter.qml) when cycling ambient mode:
     - `"󰍹 Ambient: Dynamic (Idle Only)"`
     - `"󰈈 Ambient: Always On"`
     - `"󰍹 Ambient: Disabled"`

---

## 3. Verification Matrix

| Test Case | Action | Expected Output | Actual Output | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Clean Background** | Inspect `hudContainer` | Only `DesktopAmbientSlate` rendered | 0 brackets, 0 heatmap, 0 side telemetry | **PASS** |
| **Dynamic Mode (Active)** | Query IPC `ambient getSummary` | `active: false` when user active | `{"enabled":true,"alwaysOn":false,"active":false,"idle":false}` | **PASS** |
| **Always On Mode** | IPC `ambient toggleAlwaysOn` | `active: true` even when not idle | `{"enabled":true,"alwaysOn":true,"active":true,"idle":false}` | **PASS** |
| **Knowledge Graph** | `graphify update .` | Ast cache and graph updated | Rebuilt cleanly (2411 nodes, 2769 edges) | **PASS** |
