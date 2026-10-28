# Zenia local AI bridge (implementation status)

This branch now contains the web-side contract plus an initial Android-native loader project for connecting the existing Zenia Quest Companion game to a local model runner. The original game UI and gameplay are intentionally kept intact.

## What changed

- `Zenia Quest Companion.html` now exposes `window.ZeniaAI`.
- Meaningful game events send context for short Indonesian companion comments: level-up, nearby enemies, enemy/boss defeat, critically low HP, and ambient village/exploration moments.
- The game renders a Sims-style speech bubble beside the companion; bubble text is shown only after it receives the model's generated response.
- A minimum 10-second interval is enforced and only one inference request is in flight at a time.
- There are no canned/fallback companion lines. If the native bridge is absent, no AI bubble appears and gameplay continues normally without network requests.

## Android loader prototype

The new `android-loader/` folder contains a minimal Android Studio project, a WebView wrapper that bundles the updated game HTML, a **Muat AI lokal** control embedded in the game, a local GGUF picker using Android's Storage Access Framework, and a JNI bridge linked to llama.cpp (pinned to `b4510`). The selected model is accessed through an open file descriptor rather than being copied into app storage. The Android manifest has no `INTERNET` permission. See `android-loader/README.md` for build instructions and prototype limitations.

## Native Android bridge

The Android wrapper exposes `ZeniaNativeAI.pickModel()` for the in-game loader button and `ZeniaNativeAI.requestComment(payloadJson)` for contextual comments. After local inference, it calls `window.ZeniaAI.receive(requestId, generatedText)` using JSON-quoted arguments.

## Model/runtime requirements

- Use the existing Gemma 3 1B GGUF file selected by the user; do not download a model from the network.
- Inference must stay on-device. Do not add the Android `INTERNET` permission.
- Do not use `llama.rn`, Termux, or a cloud inference endpoint.
- OfflineLLM v5.1.1 is a **technical reference only**. Its signed APK is not a runtime dependency and must not be repackaged.
- The pinned llama.cpp revision is intended to support Gemma 3 GGUF, and the prompt uses Gemma 3 turn markers. The exact Gemma 3 1B file still needs a successful on-device load and inference test.
- Model selection is explicit. The current prototype does not automatically copy the selected GGUF; it keeps the selected file descriptor open while the model is loaded.

## Important status

This branch now includes an initial Android app wrapper and JNI inference path, but it is still a **prototype, not a verified build**. No APK has been built or tested on the user's phone yet. The exact Gemma 3 1B GGUF tokenizer/runtime compatibility and file-provider mmap behavior still need on-device verification. The standalone HTML game remains usable as before; AI comments require the Android wrapper and a successfully loaded local model.
