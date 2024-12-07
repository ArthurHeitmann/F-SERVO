# EST/Effects

Special effects

file extensions: est, sst

![est editor](assets/help/img/est_editor.png)

An EST file is made up of multiple sub-effects/records, that in game are played at the same time and can interact with each other.
Select a record or one of its sub parts to edit it.

Mostly you just have to play around with the values to see what they do.

Records and their sub parts can be disabled, removed and copy & pasted.

After making changes, save the file (Ctrl+S or Save button in top left corner). Then repack it's dat and any parent DATs.

**Note on textures**

Example:  
Texture file ID: 7  
Texture index: 17  

This references the texture with index 17 in 007.wta.

If "Is single frame" is 0, the texture is animated, displaying all images from the wta in sequence, starting at the texture index.
