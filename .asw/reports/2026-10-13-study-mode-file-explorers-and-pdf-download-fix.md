# Engineering Report: Study Mode File Explorer Whitelist & PDF Download Support

**Date**: 2026-10-13  
**Topic**: Study Mode Window Guardian: Unblocking File Explorers, Desktop Portals, and ICAI PDF Downloads  
**Status**: Applied & Live in Active Session  

---

## 1. Problem Description

While in Study Mode (`CA / ICAI Study`), the user attempted to view and download study material PDFs from ICAI's CDN (`resource.cdn.icai.org/88015bos-aps2231-ch1.pdf`). Two critical failure modes occurred:

1. **ICAI PDF Tab Termination**:
   - Brave displays direct PDF URLs using the filename as the tab title (e.g. `88015bos-aps2231-ch1.pdf`).
   - The whitelist only searched for `"boslive"` and `"icai"`. Because the filename did not contain the exact substring `"boslive"` or `"icai"`, `scripts/study-mode.py` flagged the study PDF as unauthorized and closed the tab via `Ctrl+W`.

2. **File Chooser / Explorer Instant Termination**:
   - When triggering "Save As" / download, the system spawns a file chooser window (`xdg-desktop-portal-gtk`, `kdialog`, `zenity`, or Brave child dialog).
   - `ALLOWED_CLASSES` only permitted `dolphin`. Portals (`xdg-desktop-portal-gtk`, `org.freedesktop.impl.portal.desktop.gtk`), GNOME/KDE/XFCE file explorers (`nautilus`, `nemo`, `thunar`, `pcmanfm`, `caja`, `yazi`, `ranger`), and file picker dialogs were absent from the whitelist.
   - The study daemon running every 300ms detected the portal / file manager window as non-whitelisted and killed the process immediately (`SIGTERM`).

---

## 2. Root Cause Analysis

- **Location**: [`scripts/study-mode.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/study-mode.py)
- **Functions**: `enforce_distractions()`
- **Flaws**:
  1. `ALLOWED_CLASSES` omitted desktop integration portals (`xdg-desktop-portal-*`), alternative file managers, and file choosers.
  2. Tab title matching lacked support for generic PDF documents (`.pdf`), ICAI Board of Studies abbreviation (`bos`), and download action titles (`Save File`, `Save As`, `Open File`).
  3. Brave child file picker dialogs with class `brave` and title `Save File` were evaluated as website tabs rather than file operations.

---

## 3. Implementation Details

1. **Comprehensive File Explorer & Portal Whitelist**:
   - Added all primary Linux file managers:
     - `dolphin`, `org.kde.dolphin`
     - `nautilus`, `org.gnome.nautilus`
     - `nemo`, `org.nemo`
     - `thunar`, `org.xfce.thunar`
     - `pcmanfm`, `pcmanfm-qt`, `org.lxde.pcmanfm`
     - `caja`, `org.mate.caja`
     - `spacefm`, `krusader`, `doublecmd`, `mc`, `ranger`, `yazi`, `vifm`
     - `ark`, `file-roller`, `engrampa`, `peazip`
   - Added all Wayland/Hyprland desktop portals and picker dialogs:
     - `xdg-desktop-portal-gtk`, `org.freedesktop.impl.portal.desktop.gtk`
     - `xdg-desktop-portal-kde`, `org.freedesktop.impl.portal.desktop.kde`
     - `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-wlr`
     - `kdialog`, `zenity`, `yad`, `qarma`, `gcr-prompter`, `polkit-*`

2. **Dynamic Detection Engine (`is_file_manager_or_dialog`)**:
   - Evaluates both `class` and `initialClass` against file manager patterns.
   - Evaluates window titles for standard file operation dialogs (`Save File`, `Save As`, `Open File`, `Select Folder`, `File Upload`, `Choose File`).
   - Prevents Brave-hosted save dialogs from being treated as unauthorized browser tabs.

3. **PDF & ICAI Keyword Expansion (`ALLOWED_BRAVE_KEYWORDS`)**:
   - Added `.pdf` and `pdf` wildcard match so any study PDF document stays open.
   - Added `"bos"` (ICAI Board of Studies prefix) and CDN domains (`resource.cdn.icai.org`, `cdn.icai.org`, `icai.org`).
   - Added download action keywords (`save`, `save file`, `save as`, `open file`, `download`).

4. **Live Seamless Daemon Reload**:
   - The running study mode daemon (PID `248398`) was seamlessly restarted to PID `298773`.
   - The active study countdown continues without interruption (680s remaining).

---

## 4. Verification

| Scenario | Input | Expected Result | Actual Result |
| :--- | :--- | :--- | :--- |
| ICAI BOS Chapter PDF | `88015bos-aps2231-ch1.pdf` | Tab permitted | **PASS** (`is_allowed = True`) |
| Desktop File Chooser Portal | `xdg-desktop-portal-gtk` | Window permitted | **PASS** (`is_allowed_class = True`) |
| Brave Save File Dialog | `class: brave`, `title: Save File` | Dialog permitted | **PASS** (`is_file_manager_or_dialog = True`) |
| Nautilus / Files | `org.gnome.nautilus` | Window permitted | **PASS** (`is_allowed_class = True`) |
| Thunar | `thunar` | Window permitted | **PASS** (`is_allowed_class = True`) |
| Distraction Website | `youtube - brave` | Blocked & closed | **PASS** (`distraction detected`) |
| Distraction Application | `spotify` | Paused & closed | **PASS** (`blocked`) |
