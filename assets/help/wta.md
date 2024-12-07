# WTA/WTB

Container that holds multiple textures (usually in DDS format).

file extensions: wta, wtp, wtb

## WTA+WTP and WTB difference

Textures are stored either in a single .wtb file or in separate .wta and .wtp files. The wta is in the DAT, whereas the wtb and wtp are in the DTT.

## Extracting

Open a .wta or .wtb file by dragging & dropping it into the File Explorer or by clicking the folder icon and selecting the file.

When opening a .wta or .wtb file, all textures are extracted to disk. When opening a WTA and the corresponding WTP is not found, the file will fail to load.

## Editing textures

![texture editor](assets/help/img/wta_edit.png)

After making changes, save the file (Ctrl+S or Save button in top left corner). This will save both wta+wtp (or wtb).
Then you have to repack the relevant .dat and .dtt files. The location of the WTP is shown at the top. Click the DTT name to open it to the File Explorer.

### Replacing textures

Find the texture you want to edit, based on the id or preview image. Either change the texture path directly or click the folder icon and select a new texture.

### Adding and removing textures

Press the (+) button to add a new texture. To remove a texture, click the delete button.

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
