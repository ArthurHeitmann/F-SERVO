# F-SERVO (File and Scripts EditoR Version One)

A tool for modding a variety of files in Nier:Automata

Supported file types:
- DAT, DTT
- PAK, YAX, XML (xml quest scripts)
- BIN (ruby quest scripts)
- BXM (XML config files)
- WTA, WTP, WTB (texture files)
- BNK, WEM, WAI, WSP (audio files)
- TMD (localized UI text)
- MCD (localized UI text)
- SMD (localized subtitles)
- FTB (fonts)
- CPK extract
- Save files (SlotData_X.dat)
- EST (effects)

## Installation

Go to the [releases](https://github.com/ArthurHeitmann/F-SERVO/releases) page and download the latest `F-SERVO_x.x.x.7z` file. Extract the archive and run `F-SERVO.exe`.

## Usage

See the incomplete [wiki](https://github.com/ArthurHeitmann/F-SERVO/wiki/Getting-Started).

## Screenshots

![image](https://user-images.githubusercontent.com/37270165/221270764-b10a7810-f704-47c6-9b1b-fe652d00ee05.png)  
Editing quest scripts

![image](https://user-images.githubusercontent.com/37270165/222829431-4c1f1123-f6a5-48bc-b211-07cd5126658b.png)  
Music replacement & loop point editing

![image](https://github.com/ArthurHeitmann/F-SERVO/assets/37270165/36770284-fb7d-4293-9656-d64e28f3e74f)  
MCD editing

## Support

- Open an issue on this repository
- [Nier Discord modding server](https://discord.gg/ngAK7rT)
- My Discord name: @raiderbv

## Building (for developers only)

1. [Setup Flutter for Windows](https://docs.flutter.dev/get-started/install/windows)

2. Git clone this repository

3. Get all assets
   1. Update git submodules with
      ```bat
      git submodule update --init
      ```
   2. Download additional assets from [here](https://github.com/ArthurHeitmann/F-SERVO/releases/tag/assetsV0.6.0) and extract the folders inside into the `assets` folder. (This is so that the raw git repo isn't 100+ MB large)

4. Update dependencies with
   ```bat
   flutter pub get
   ```

5. Run with your IDE of choice or for release build `flutter build windows --release`
