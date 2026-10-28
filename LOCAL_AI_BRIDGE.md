# Zenia local AI bridge (implementation status)

This branch contains the web-side contract and an Android-native loader project connecting the existing Zenia Quest Companion game to a local model runner. The original game UI and gameplay are intentionally kept intact.

## What changed

- `Zenia Quest Companion.html` exposes `window.ZeniaAI`.
- Meaningful game events send context for short Indonesian companion comments: level-up, enemy/boss defeat, critically low HP, and ambient village/exploration moments.
- The game renders a Sims-style speech bubble beside the companion; text appears only after receiving model-generated output.
- A minimum 10-second interval is enforced and only one inference request is in flight at a time.
- There are no canned/fallback companion lines. If the native bridge is absent, no AI bubble appears and gameplay continues normally without network requests.

## Android loader prototype

The `android-loader/` folder contains an Android Studio project, a WebView wrapper bundling the updated game HTML, a **Muat AI lokal** control, a local GGUF picker, and a JNI bridge linked to llama.cpp. The native API and pinned llama.cpp revision (`b10472`) are aligned with the engine revision used by OfflineLLM v5.1.1. The selected model is accessed through an open file descriptor rather than copied into app storage. The Android manifest has no `INTERNET` permission.

## Native Android bridge

The Android wrapper exposes `ZeniaNativeAI.pickModel()` and `ZeniaNativeAI.requestComment(payloadJson)`. After local inference, it calls `window.ZeniaAI.receive(requestId, generatedText)` using JSON-quoted arguments.

## Model/runtime requirements

- Use the existing Gemma 3 1B GGUF file selected by the user; do not download a model from the network.
- Inference must stay on-device. Do not add the Android `INTERNET` permission.
- Do not use `llama.rn`, Termux, or a cloud inference endpoint.
- OfflineLLM v5.1.1 is a **technical reference only**. Its signed APK is not a runtime dependency and must not be repackaged.
- The exact Gemma 3 1B GGUF still needs successful loading and inference verification on the target phone.
- Model selection is explicit. The prototype keeps the selected file descriptor open while the model is loaded and does not automatically copy the GGUF.

## Important status

This remains a **prototype, not a verified build**. The native API and engine pin have been updated to match the OfflineLLM v5.1.1 engine revision, and the CI NDK environment setup has been corrected. A successful APK build and on-device inference have not yet been confirmed. The exact model and file-provider mmap/seek behavior still require verification. The standalone HTML game remains usable as before; AI comments require the Android wrapper and a successfully loaded local model.
