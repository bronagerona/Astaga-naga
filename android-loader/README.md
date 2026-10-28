# Zenia Local AI — Android loader prototype

This Android wrapper is the first native loader for the existing **Zenia Quest Companion** game. It does not redesign gameplay. It packages the same HTML as an offline WebView asset and exposes `ZeniaNativeAI.requestComment(payloadJson)` to the game.

## Current flow

1. Build and install this Android project from Android Studio.
2. Tap **Muat Gemma lokal** and select the Gemma 3 1B GGUF file already on the device.
3. The app opens the selected document through Android's Storage Access Framework and keeps its file descriptor open. It does **not** download or copy the GGUF into app storage.
4. llama.cpp loads the local file and generates a short Indonesian comment from the game event/context.
5. The response is returned to `window.ZeniaAI.receive(id, text)`; the existing game code displays the companion bubble.

The selected document provider must expose a seekable local file descriptor. If a provider returns a pipe or blocks mmap, try selecting the same file through the device's local Files app. No model is copied automatically.

## Offline/privacy behavior

- The Android manifest intentionally has **no `INTERNET` permission**.
- No cloud endpoint or remote inference is used.
- `llama.cpp` source is fetched at **build time** by CMake and pinned to tag `b4510`; that is a build dependency, not an inference service.
- The GGUF stays where the user selected it. The app retains the open descriptor while the model is loaded.
- No canned lines are used. If the model isn't loaded or returns no text, no companion comment is shown.

## Build

Open the `android-loader` folder in Android Studio with Android SDK 35, Android NDK, CMake 3.22.1, and a compatible JDK installed. Let Gradle/CMake resolve the pinned llama.cpp source, then build/install the `app` configuration. The native target currently targets `arm64-v8a`.

## Important prototype status

This is the initial loader implementation and **has not yet been built or tested on the user's phone**. Gemma 3 1B GGUF support depends on the exact model metadata/tokenizer and the pinned llama.cpp build; successful compilation and on-device load/inference still need verification. The model prompt uses Gemma 3's turn markers. Do not treat the loader as confirmed working until that test passes.
