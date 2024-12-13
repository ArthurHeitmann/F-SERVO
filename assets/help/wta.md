# WTA/WTB

Container that holds multiple textures (usually in DDS format).

file extensions: wta, wtp, wtb

## WTA+WTP and WTB difference

Textures are stored either in a single .wtb file or in separate .wta and .wtp files. The wta is in the DAT, whereas the wtb and wtp are in the DTT.

## Extracting

Open a .wta or .wtb file or their extracted folder by dragging & dropping it into the File Explorer or by clicking the folder icon and selecting the file.

When opening a .wta or .wtb file for the first time, all textures are extracted to disk. When reopening the file, the textures are loaded from the extracted folder, or individual textures are re-extracted if missing.

## Editing textures

![texture editor](assets/help/img/wta_edit.png)

After making changes, save the file (Ctrl+S or Save button in top left corner). This will save both wta+wtp (or wtb).
Then you have to repack the relevant .dat and .dtt files. The location of the WTP is shown at the top. Click the DTT name to open it to the File Explorer.

### Replacing textures

Find the texture you want to edit, based on the id or preview image. Either change the texture path directly or click the folder icon and select a new texture.

### Adding and removing textures

Press the (+) button to add a new texture. To remove a texture, click the delete button.

### Replace or add all textures from a folder

Press the floating button in the bottom left corner and select a folder with textures inside. F-SERVO will find all dds files with an id.
If a texture id is already in the WTA, its path will be replaced. Otherwise, a new texture will be added.

## Notes

- Changing the id is only relevant when adding new textures
- Changing flags is not needed
- The order of textures only matters for effect textures

## Tips

- Click the preview image to save the texture as a png
- Textures generally should be in DDS format
  - DXT1 (BC1) for textures without transparency
  - DXT5 (BC3) for textures with transparency
- Available tools for exporting DDS from PNG
  - Built in tool in Sidebar > Tools > Convert Textures
  - Paint.NET
  - GIMP
  - Photoshop with NVIDIA or Intel DDS plugin
  - NVIDIA Texture Tools
