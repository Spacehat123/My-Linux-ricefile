# Gradio 6 Chatbot Schema Remediation Report

**Date**: 2026-11-20  
**Target**: `scripts/chat-ui.py` (AI Image Studio Chat Interface)  
**Status**: Resolved & Service Restarted  

---

## 1. Executive Summary

When attempting to generate images using the detached Chat WebUI (`http://127.0.0.1:7860`), prompt submission triggered a red **"Error"** bubble in the interactive chatbot window. The underlying traceback in `/tmp/cool-shell-chat-ui.log` revealed:

```
gradio.exceptions.Error: "Data incompatible with messages format. Each message should be a dictionary with 'role' and 'content' keys or a ChatMessage object."
```

Gradio 6 completely deprecates legacy 2D list/tuple formatting (`[[user_msg, bot_msg], ...]`) and mandates that chatbot state conform strictly to the `messages` schema (`list[dict]` containing `"role"` and `"content"`). Furthermore, returning a tuple `(path, caption)` for multimodal outputs causes a `ValueError: Invalid message for Chatbot component`.

The implementation in [`scripts/chat-ui.py`](file:///home/pranc/.config/quickshell/cool-shell/scripts/chat-ui.py) has been re-architected to natively support Gradio 6's message format for single-turn, multi-turn, text-only, and multimodal (img2img) requests.

---

## 2. Root Cause Analysis

1. **`user_submits` formatting mismatch**:
   - The handler previously executed `history.append([user_msg, None])`.
   - In Gradio 6, `gr.Chatbot` defaults to `type="messages"`. Gradio's internal `_check_format(value)` throws an unhandled exception when items in `history` are lists rather than dictionaries with `"role"` and `"content"`.
2. **`bot_generates` index assumption**:
   - The generator attempted to manipulate `history[-1][0]` and `history[-1][1]`, which are incompatible with dictionary structures.
3. **Multimodal return format**:
   - In Gradio 6, returning `(saved_path, caption_meta)` is rejected by `_postprocess_content`. The valid Gradio 6 multimodal structure requires a list: `[{"path": saved_path}, caption_meta]`.

---

## 3. Implemented Changes

### A. Message Normalization & Safe Extraction
Implemented `extract_prompt_and_files(message)`:
- Safely unwraps user messages whether they arrive as raw strings, dictionaries, lists of components, or preprocessed Gradio `TextMessage`/`FileMessage` models.
- Guarantees seamless continuity across multi-turn chats.

### B. Gradio 6 Conforming Handlers
1. **`user_submits(message, history)`**:
   - Assembles user content into Gradio 6 `messages` format:
     ```python
     user_content = []
     for f in files:
         user_content.append({"path": f})
     if raw_text:
         user_content.append(raw_text)
     if len(user_content) == 1 and isinstance(user_content[0], str):
         user_content = user_content[0]

     history.append({"role": "user", "content": user_content})
     ```
   - Gracefully rejects empty submissions without adding broken entries.
2. **`bot_generates(...)`**:
   - Appends temporary status indicator: `{"role": "assistant", "content": "🎨 *Synthesizing diffusion latents on GPU...*"}`.
   - Dispatches prompt to background daemon via `image_engine.send_prompt`.
   - On completion, updates the assistant message to `[{"path": saved_path}, caption_meta]`.
   - Wraps daemon communication in `try...except` to show inline error descriptions rather than crashing the chat UI.
3. **`refresh_gallery()`**:
   - Now reads directly from `~/Pictures/generated/chat/` (newest first), ensuring that images generated across sessions are immediately accessible in the Gallery tab.

---

## 4. Verification & State Inspection

- **Syntax Validation**: Checked via `python3 -m py_compile scripts/chat-ui.py` (0 errors).
- **Schema Validation**: Unit tested Gradio 6 `postprocess` and `preprocess` roundtrips with mock multimodal entries (all passed).
- **Process Status**:
  - `image-daemon.py` (PID 157941): Loaded in CPU RAM (156 MB), ready on `/tmp/cool-shell-image.sock`.
  - `chat-ui.py` (PID 205531): Running cleanly, listening on `127.0.0.1:7860`.
  - `curl -sI http://127.0.0.1:7860` returns `HTTP/1.1 200 OK`.
- **System Isolation**: `Super + G` island prompt panel and single-file output policy remain completely untouched and independent.
