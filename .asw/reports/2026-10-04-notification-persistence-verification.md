# Dynamic Island Notification Persistence Verification Report

**Date**: 2026-10-04  
**Scope**: Dynamic Island / Notification Center lifecycle, toast banner management, and persistence audit in `cool-shell`.  
**Status**: Verified & Operational  

---

## 1. Executive Summary

A critical defect was identified and resolved in the Quickshell notification subsystem. Previously, incoming desktop notifications would appear as transient toast popups, but opening the Dynamic Island Notification Center would display *"No notifications"*.

### Root Causes
1. **Delegate Destruction Side-Effect**: In [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml), a lifecycle hook `Component.onDestruction: notification.tracked = false` was present. Whenever a toast banner timed out and was unmounted, or whenever the Dynamic Island panel closed and its delegates were destroyed, this hook forcibly marked the underlying notification as untracked. In Quickshell, untracking a notification immediately expels it from `notificationServer.trackedNotifications`.
2. **Server-Level Expiration on Toast Timers**: In [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml), the automatic timeout timer called `root.notification.expire()`. This instructed DBus / Quickshell's notification server to expire and drop the notification after 4–6 seconds, ensuring the notification was dead before the user could ever open the Notification Center.
3. **Coupling between Toast Popups and Tracked Notifications**: [`island/NotificationPopups.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationPopups.qml) directly bound its `model` to `notificationServer.trackedNotifications`. The author had conflated "hiding a transient toast from the screen" with "destroying/expiring the notification itself".

---

## 2. Architecture & Implementation Changes

### 2.1 Decoupling Ephemeral Toasts from Persistent Notification History
In [`island/NotificationPopups.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationPopups.qml):
- Replaced the direct model binding to `trackedNotifications` with an explicit `property var activeToasts: []`.
- Added `showToast(notification)` and `dismissToast(id)`.
- Popups only manage active on-screen alert cards. When an alert times out, `dismissToast(id)` removes it from the screen without touching the notification's tracked state on the server.
- Window visibility is constrained to `!IslandHub.dnd && activeToasts.length > 0`, avoiding empty overlay layers.

### 2.2 Mode-Aware Notification Cards
In [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml):
- Added `property bool isPopup: false` and `signal dismissToastRequested()`.
- **Auto-expire Timer Guard**: `running: root.isPopup && root.timeout > 0 && !hoverArea.containsMouse`. When triggered in `isPopup` mode, it emits `dismissToastRequested()`, cleanly hiding the toast banner while keeping the notification alive in history.
- **Removed Destruction Hook**: Deleted `Component.onDestruction: notification.tracked = false` entirely.
- **Explicit Dismissal**: Clicking the `×` button or an action button dismisses the toast from the screen (if popup) and calls `notification.dismiss()` on the server.

### 2.3 Shell Notification Dispatch
In [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml):
- In `NotificationServer.onNotification`:
  ```qml
  notificationPopups.showToast(notification);
  ```
- Tracked count exposed in `IpcHandler { target: "island" }.getSummary()` for verification and monitoring:
  ```qml
  trackedCount: notificationServer.trackedNotifications && notificationServer.trackedNotifications.values ? notificationServer.trackedNotifications.values.length : 0
  ```

### 2.4 Scrollable, High-Capacity Notification Center
In [`island/panels/NotifCenterPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/NotifCenterPanel.qml):
- Wrapped the notification list in a bounded, scrollable `Flickable` (`implicitHeight: Math.min(420, Math.max(80, content.implicitHeight))`).
- Delegates run in `isPopup: false` mode (no auto-timeout).
- "Dismiss all" safely iterates through all tracked notifications and dismisses each explicitly.

---

## 3. Verification & Test Matrix

| Test Case | Procedure | Expected Result | Actual Result | Status |
|---|---|---|---|---|
| **1. Toast Banner Trigger** | Send DBus notification via `notify-send` | Toast popup appears on screen with 5s timeout | Appeared with correct styling & timer | **PASS** |
| **2. Toast Auto-Fade** | Wait 7 seconds for toast to fade | Toast disappears from screen; `trackedCount` remains 1 | Toast disappeared; `trackedCount: 1` | **PASS** |
| **3. Notification Panel Read** | Open Dynamic Island notification panel via IPC | `unread` bubble resets to 0; notification is listed in panel | Notification rendered with body and header; `unread: 0` | **PASS** |
| **4. Panel Close & Persistence** | Close Island panel and re-query summary | Notification stays in `trackedCount`; delegates not destroyed | `trackedCount: 1` persisted | **PASS** |
| **5. Multiple Notifications** | Send batch of notifications (`notify-send`) and let toasts fade | All notifications accumulate in history | `trackedCount: 5` accumulated | **PASS** |
| **6. Multi-Cycle Retention** | Repeatedly open and close Dynamic Island panel | Notifications remain in panel indefinitely until dismissed | `trackedCount: 5` remained intact across 3 open/close cycles | **PASS** |
| **7. Game Mode Invariance** | Verify Game Mode status | Game Mode must remain disabled (`gameMode: false`) | Game Mode strictly OFF (`false`) | **PASS** |

---

## 4. Modified Files Reference

- [`island/NotificationCard.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationCard.qml) — Removed toxic destruction hook; added `isPopup` mode and non-destructive toast dismiss signal.
- [`island/NotificationPopups.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/NotificationPopups.qml) — Decoupled toast display from persistent notification model.
- [`island/panels/NotifCenterPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/NotifCenterPanel.qml) — Added `Flickable` scrolling and non-expiring delegates.
- [`shell.qml`](file:///home/pranc/.config/quickshell/cool-shell/shell.qml) — Dispatches incoming toasts to `notificationPopups.showToast()` and reports `trackedCount`.
