# Zenia Quest — Local AI companion comments

This Android wrapper uses the same React Native + WebView + `llama.rn` loading approach as the successful PROJECT WINGMATE build, simplified to **one local GGUF model for comments only**.

## Build
GitHub Actions workflow: `.github/workflows/zenia-local-ai.yml`

- Choose a Gemma 3 1B GGUF file on the device.
- The app copies the selected model into app cache and tests local inference before opening the game.
- The HTML game is bundled as an Android asset and runs in a WebView.
- Only short comment requests are sent from game events to the native local model.
- The model response is displayed in a speech bubble beside the wolf companion.

The model never returns movement or combat decisions. Companion movement, attacks, quests, combat, and save data remain controlled by the existing Zenia game code. There is no cloud inference endpoint.

## Build artifact
On a successful GitHub Actions run, download the `zenia-local-ai-debug-apk` artifact.
