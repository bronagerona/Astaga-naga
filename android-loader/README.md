# Zenia Local AI — Android loader prototype

This Android wrapper connects the existing **Zenia Quest Companion** game to a local GGUF model using a native llama.cpp engine. It does not redesign gameplay. The HTML includes a **Muat AI lokal** control and status label, and the same game HTML is bundled as an offline WebView asset.

## Current flow

1. Build and install this Android project.
2. Tap **🤖 Muat AI lokal** (or the loader button in the top bar) and select the Gemma 3 1B GGUF file already on the device.
3. The app opens the selected document through Android's Storage Access Framework and keeps its file descriptor open. It does **not** download or copy the GGUF into app storage.
4. llama.cpp loads the local file and generates a short Indonesian comment from the game event/context.
5. The response is returned to `window.ZeniaAI.receive(id, text)`; the existing game code displays the companion bubble.

The selected document provider must expose a seekable local file descriptor. If a provider returns a pipe or blocks memory mapping, try selecting the same file through the device's local Files app. No model is copied automatically.

## Offline/privacy behavior

- The Android manifest intentionally has **no `INTERNET` permission**.
- No cloud endpoint or remote inference is used.
- llama.cpp is fetched only at **build time**, pinned to `b10472` (the llama.cpp revision used by OfflineLLM v5.1.1), not used as a remote inference service.
- The GGUF stays where the user selected it. The app retains the open descriptor while the model is loaded.
- No canned lines are used. If the model isn't loaded or returns no text, no companion comment is shown.

## Build

Open `android-loader` in Android Studio with Android SDK 35, Android NDK, CMake 3.22.1, and JDK 17. Let Gradle/CMake resolve the pinned llama.cpp source, then build/install the `app` configuration. The native target currently targets `arm64-v8a`.

## Verification status

This is still a prototype and has **not yet been built or tested on the user's phone**. The native API and llama.cpp pin have been aligned to the engine version used by OfflineLLM v5.1.1, but compilation, loading this exact Gemma 3 1B GGUF, and on-device inference must still pass before compatibility can be claimed.
