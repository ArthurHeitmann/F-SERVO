# BNK/Audio

Wwise generated soundbank that holds audio files and controls how sounds and music are played.

file extensions: bnk, wem

## WEM replacement

![wem replacement](assets/help/img/wem_replacement.png)

1. Open a .wem from the "WEM files" list
2. "Select WAV or WEM" to replace the file
3. Replace WEM
4. Save

## Wwise project generation

Right click a BNK and select "Create Wwise Project"

![wwise project generation](assets/help/img/wwise_project_gen.png)

Options:

- Source BNKs: Add more than one BNK to create a project with multiple BNKs
- Include from BNK: Select what data to include from the BNK  
  To include original streamed audio in the project, in the settings "Wem Extract Directory" has to be set to the folder where stream CPKs are extracted.
- Seek table: auto enabled when generating BGM projects
- Streaming & zero latency
  - Disabled: Newly generated BNKs will have all WEMs in memory
  - Enabled: Newly generated BNKs will stream audio
- ID randomization
  - Disabled: Will recreate original BNK almost perfectly
  - Enabled: For use with modding. To change settings new IDs have to be generated


## Other tools

### Convert stream audio to in-memory audio

Right click a WEM in the File Explorer. If it's streamed, you can "Make in memory". To work, the "Wem Extract Directory" has to be set in the settings.

### Remove prefetched WEMs

Usually streamed audio has a short prefetched audio file that is stored in the BNK. To remove it, right click a BNK and "Remove prefetched WEMs".

### Built in playlist editor

BNK playlist can to some extent be edited directly in F-SERVO. Open a MusicPlaylist from the Object Hierarchy. Things that can be edited:

- Entry and exit cues
- Clip durations and positions
- Clips can be deleted and duplicated
- Remove volume and lowpass curves

The audio player will try to approximate the looping behavior.
