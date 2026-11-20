# AI Studio: Zero-Persistence Input Policy & Single-Output Lifecycle

- **Date**: 2026-11-19
- **Scope**: Ephemeral data policy, zero input persistence, prompt anonymity, and deterministic single-output image storage
- **Affected Files**:
  - [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py)
  - [`scripts/image-engine.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-engine.py)
  - [`island/panels/AiPromptPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml)
  - [`island/IslandHub.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/IslandHub.qml)

---

## 1. Executive Summary
Implemented strict zero-persistence data handling for the on-device AI Studio. Prompts and input images are never saved to disk or shell configuration; any temporary input files are purged immediately; prompt text is completely stripped from logs and PNG metadata; and output generation is restricted to strictly **one single deterministic file** (`~/Pictures/generated/ai_output.png`) that overwrites on every generation.

---

## 2. Policy Implementation Details

### 2.1 Single Output Copy Guarantee
- **File Location**: `~/Pictures/generated/ai_output.png`.
- **Behavior**: Every new generation directly writes to `ai_output.png`.
- **Cleanup**: Pre-generation routines scan `~/Pictures/generated/` for any legacy `ai_*.png` files and unlink them, ensuring strictly one single generated image exists on the drive at any time.

### 2.2 Complete Prompt Anonymity & Zero Logging
- **Memory-Only Processing**: User prompts are handled purely in RAM, passed across the local UNIX socket, and converted into CLIP embeddings in-memory.
- **No Disk Storage**: Prompts are never written to `ai-settings.json`, shell configs, or text logs.
- **No Log Output**: Distilled positive/negative prompt printouts to stdout/stderr were replaced with non-revealing generic notifications (`[*] Prompt distilled into memory.`).
- **No EXIF / PNG Info**: Generated images are saved without any embedded prompt metadata or text chunks.

### 2.3 Ephemeral Reference Image Handling
- **Immediate State Purge**: In [`island/panels/AiPromptPanel.qml`](file:///home/pranc/.config/quickshell/cool-shell/island/panels/AiPromptPanel.qml), both `submitPrompt()` and Escape cancel immediately wipe `promptInput.text` and call `IslandHub.clearAiReferenceImage()`.
- **Temporary File Auto-Deletion**: If an input photo originates from a temporary location (e.g. `/tmp/` or cache directories), [`scripts/image-daemon.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/image-daemon.py) automatically unlinks it immediately after loading the pixel matrix into RAM.
- **No Image Duplication**: No intermediary thumbnails or scaled copies are written to disk.
