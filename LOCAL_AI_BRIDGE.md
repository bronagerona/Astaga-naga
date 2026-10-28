# Zenia local AI bridge (implementation status)

This branch now contains the web-side contract plus an initial Android-native loader project for connecting the existing Zenia Quest Companion game to a local model runner. The original game UI and gameplay are intentionally kept intact.

## What changed

- `Zenia Quest Companion.html` now exposes `window.ZeniaAI`.
- Meaningful game events send context for short Indonesian companion comments: level-up, nearby enemies, enemy/boss defeat, critically low HP, and ambient village/exploration moments.
- The game renders a Sims-style speech bubble beside the companion; bubble text is shown only after it receives the model's generated response.
- A minimum 10-second interval is enforced and only one inference request is in flight at a time.
- There are no canned/fallback companion lines. If the native bridge is absent, no AI bubble appears and gameplay continues normally without network requests.

## Android loader prototype\n\nThe new `android-loader/` folder contains a minimal Android Studio project, a WebView wrapper that bundles the existing HTML, a local GGUF picker using Android's Storage Access Framework, and a JNI bridge linked to llama.cpp (pinned to `b4510`). The selected model is accessed through an open file descriptor rather than being copied into app storage. The Android manifest has no `INTERNET` permission. See `android-loader/README.md` for build instructions and prototype limitations.\n\n## Native Android bridge contract

The Android WebView host must expose a JavaScript interface named `ZeniaNativeAI` with a method equivalent to:

```kotlin
@JavascriptInterface
fun requestComment(payloadJson: String)
```

Parse the JSON payload, pass its event/context to a **local** GGUF inference engine, then deliver the completed response back into the WebView:

```javascript
window.ZeniaAI.receive(requestId, generatedText)
```

For example, the native host can call `evaluateJavascript` with JSON-safe arguments. Do not concatenate raw model output into executable JavaScript; encode/quote values safely.

## Model/runtime requirements

- Use the existing Gemma 3 1B GGUF file selected by the user; do not download a model from the network.
- Inference must stay on-device. Do not add the Android `INTERNET` permission.
- Do not use `llama.rn`, Termux, or a cloud inference endpoint.
- OfflineLLM v5.1.1 is a **technical reference only**. Its signed APK is not a runtime dependency and must not be repackaged.
- Before choosing the native engine, verify that its GGUF tokenizer/chat-template path supports Gemma 3 1B. General GGUF loading alone does not prove template compatibility.
- Keep model selection/import explicit. If copying a picked model into app-private storage is required by the engine, tell the user before copying because the GGUF may be large.

## Important status

This branch now includes an initial Android app wrapper and JNI inference path, but it is still a **prototype, not a verified build**. No APK has been built or tested on the user's phone yet. The exact Gemma 3 1B GGUF tokenizer/runtime compatibility and file-provider mmap behavior still need on-device verification. The standalone HTML game remains usable as before; AI comments require the Android wrapper and a successfully loaded local model.
