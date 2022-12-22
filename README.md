# Nier Scripts Editor

A tool for modding a variety of files in Nier:Automata. Primarily for editing quest scripting files.

Supported file types:
- DAT
- PAK
- YAX
- XML
- TMD
- SMD
- MCD
- BIN

## Building

1. [Setup Flutter for Windows](https://docs.flutter.dev/get-started/install/windows)

2. Git clone this repository

3. Get all assets
   1. `git submodule update --init`
   2. Download additional assets from [here](https://github.com/ArthurHeitmann/NierScriptsEditor/releases/tag/assetsV0.4.0) and extract the folders inside into the `assets` folder. (This is so that the raw git repo isn't 100+ MB large)

4. Run with your IDE of choice or for release build `flutter build windows --release`
