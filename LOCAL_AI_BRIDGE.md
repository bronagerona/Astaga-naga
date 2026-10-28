# Zenia local AI bridge (implementation status)

This branch adds the **web-side contract** for connecting the existing Zenia Quest Companion game to an Android-native, on-device model runner. The original game UI and gameplay are intentionally kept intact.

## What changed

- `Zenia Quest Companion.html` now exposes `window.ZeniaAI`.
- Meaningful game events request a short Indonesian companion comment: level-up, enemy/boss defeat, and critically low HP.
- Requests are throttled and only one request is in flight at a time.
- The existing toast UI displays a native model response; no new game UI was added.
- If the native bridge is absent, the game continues normally without making network requests.

## Native Android bridge contract

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

This branch implements the HTML-to-native **interface only**. It does **not** yet contain the Android app wrapper, JNI/native inference backend, APK, or a verified Gemma 3 1B runtime. Until those pieces are built and tested, AI comments will only appear when a compatible native host is present; the standalone HTML game still works as before.
