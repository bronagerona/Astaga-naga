# Astaga-naga — Godot Action RPG

Offline 2D top-down pixel-style Action RPG for Android, inspired by the movement, combat feel, monster reactions, drops, and readable HUD in `Pixel_RPG_World_Upgrade_Stable.html`.

## Integrated foundation
- Godot 4 project and procedural pixel-style world; no external art downloads are required.
- Manual movement, sword attacks, attack arcs, hit particles, floating damage/EXP/gold text, enemy chase and respawn.
- Active Arcane Pulse area skill with an 8-second cooldown.
- HP, EXP, level-up stat growth, gold, potion use, elite monsters, and local save data.
- Village starter area with an Elder/shop interaction.
- Ten named maps with different environment palettes and kill-count quest gates.
- Touch joystick, on-screen action buttons, and keyboard controls for desktop testing.
- GitHub Actions workflow to validate the project and export an Android APK artifact.

## Controls
- Touch: joystick bottom-left; Potion, Skill, Attack bottom-right.
- Desktop: WASD/arrow keys to move; Space/J to attack; K skill; P potion; E interact/shop; M map/quest; Save button to persist.
- In the village, Talk / Shop interacts with the Elder. Map / Quest starts the first expedition and advances after the current map's kill target.

## Build Android
Open the **Actions** tab and run **Build Godot Android APK**. On success, download the `astaga-naga-android-apk` artifact.

## Important status
This is the first integrated code foundation, not yet a verified release. Android export and gameplay still need testing on-device. Equipment/shop depth, more distinct NPC/quest dialogue, boss encounter tuning, and production sprite assets remain follow-up improvements.
