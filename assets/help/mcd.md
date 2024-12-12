# MCD

Localized text for ui elements and subtitles.

file extensions: mcd

## Fonts

MCD files use fonts that each have a unique id, ranging from 0 to 11.
Each font has a different size and style.

The fonts 0, 6 and 8 are global fonts stored in data000.cpk\core\coreui.dat\MessCommon.mcd.

### Font textures

![mcd font debugger](assets/help/img/mcd_font_debugger.png)

Each ui_xyz.dat/messxyz.mcd comes with an ui_xyz.dtt/messxyz.wtb texture atlas.
It contains only the letters used in the mcd file.
Switch to the "Font debugger" tab to inspect it.
F-SERVO will automatically generate this texture if needed.

## Editing mcd entries

![mcd entries](assets/help/img/mcd_entries.png)

Generally you only have to edit the text field. Changing font, ids or adding/removing entries/paragraphs/lines is not needed.

Very large mcd files will be split into multiple pages. You can navigate between them using the page buttons at the top.

If you want to edit the file in your own text editor, click on the 3 dots in the top right corner and select "Export/Import as JSON".

## Font texture generation

When saving, F-SERVO will check if the texture atlas needs to be updated.

1. When no new letters are added, the texture will not be updated. In that case, exporting the .dtt is not needed, only the .dat.
2. If there are letters missing in the texture, F-SERVO will try to use the games default font, to fill in missing letters.
3. If there are letters, that are also missing in the default font or you want to use a custom font, you have use "Font overrides"

## Font overrides

![mcd font overrides](assets/help/img/mcd_font_overrides.png)

Font overrides allow you to use custom TTF or OTF fonts. A font override can be defined for one or more font ids. Options:

- **Font IDs**: Font ids to override
- **Only as fallback**:
  - Disabled: Font is applied to every letter
  - Enabled: When possible, the games default font is used. The custom font is only used for missing letters
- **TTF/OTF Path**: Path to the font file
- **Scale**: Modify the in-game font size (percentage) (1.1 = 10% larger)
- **Thickness**: Increase the font thickness (pixels)
- **Shadow Blur**: Adds a drop shadow or glow effect to the font. Not supported by all fonts (pixels)
- **X Padding**: Adds padding to the left and right of each letter. Useful when characters appear too close to each other (pixels)
- **Y Padding**: Adds padding to the top and bottom of each letter. This will make the font appear smaller. Useful when letter features reach outside their bounding box (pixels)
- **Offset**: Moves letter up or down within their bounding box. Useful when a fonts letters are not properly centered (pixels)

Global settings:

- **Letter Padding**: Adds padding between each letters bounding box. Useful when letter features reach outside their bounding box (pixels)
- **Resolution scale**: Renders all font in this texture at a higher resolution in-game, without changing its visual size (percentage) (2 = 200%)

### Note

Pressing Ctrl+S to save all files, will only save files that have been modified. However adding font overrides does not count as a modification,
because these settings are shared between all mcd files. To apply font overrides to files without edits, press the special save button in the top right corner.
This will apply font overrides to all open mcd files.
