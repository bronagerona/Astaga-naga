# Astaga-naga — Offline 2D Action RPG

**Current engine target: Defold.** The active prototype and Android build workflow are in the `defold/` folder. The older Godot foundation is retained temporarily as a reference while the Defold APK build is verified.

## Defold prototype
- Top-down, tile-like starter field with touch-to-move controls.
- Attack, Arcane Pulse skill, potion, monster chase, HP, EXP, levels, and gold.
- Initial elite-enemy and respawn loop.
- GitHub Actions workflow intended to build a debug Android APK.

## Build Android
Open the repository's **Actions** tab and run **Build Defold Android APK**. If the run succeeds, download the `astaga-naga-defold-android-apk` artifact.

## Status
This is an early playable prototype foundation, not the completed RPG. The 10 unique authored maps, village NPC/shop and quest progression, equipment inventory, save/load, boss fights, and polished pixel-art assets remain to be built and tested on an Android device. Do not treat the APK as verified until the workflow passes and the APK is tested on-device.
