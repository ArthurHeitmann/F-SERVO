# Nier Scripts Editor

A tool for modding a variety of files in Nier:Automata. Primarily for editing quest scripting files.

Supported file types:
- DAT, DTT
- PAK, YAX, XML (xml quest scripts)
- BIN (ruby quest scripts)
- TMD (translations)
- SMD (localized subtitles)
- MCD (localized UI text)

## Building

1. [Setup Flutter for Windows](https://docs.flutter.dev/get-started/install/windows)

2. Git clone this repository

3. Get all assets
   1. Update git submodules with
      ```bat
      git submodule update --init
      ```
   2. Download additional assets from [here](https://github.com/ArthurHeitmann/NierScriptsEditor/releases/tag/assetsV0.5.0) and extract the folders inside into the `assets` folder. (This is so that the raw git repo isn't 100+ MB large)

3. Update dependencies with
   ```bat
   flutter pub get
   ```

5. Run with your IDE of choice or for release build `flutter build windows --release`
