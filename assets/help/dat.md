# DAT

Container file that holds multiple files.

file extensions: dat, dtt, eff, eft, evn

## Extracting

![file explorer](assets/help/img/file_explorer_dat.png)

To open a DAT file drag & drop it into the File Explorer or alternatively click the folder icon and select the file.

When opening a DAT file for the first time, all files are extracted to disk. When reopening the same file (or folder) again, no extraction is done.
The file structure of the extracted files is the following:

- ...\\your_dat.dat
- ...\\nier2blender_extracted\\your_dat.dat\\inner_file_1.wmb
- ...\\nier2blender_extracted\\your_dat.dat\\inner_file_2.wta
- ...\\nier2blender_extracted\\your_dat.dat\\...

Note: The *nier2blender_extracted* folder name has been chosen for backwards compatibility with the Blender addons DAT extractor.

F-SERVO will by default display files it can edit in the ui. If you want to see all files, you either have to go to the extracted folder. You can right click on the file and select "Show in Explorer" to open the folder.
Alternatively in the settings enable "Show non editable DAT children".

## Editing files

You can edit supported inner files directly inside F-SERVO or edit extracted files using external tools. After editing, you have to repack the relevant DATs.
If DATs are nested (like in the above image) and you make changes to a nested file, you have to repack all parent DATs as well.

## Repacking

![repack](assets/help/img/dat_context_menu.png)

3 ways of repacking:

### Auto repack to GameData

To automatically repack files to the GameData folder, with correct subfolder structure, open settings and set "Data export path" to
`...\<Metal Gear Rising Revengeance install folder>\GameData`. To repack a DAT, right click and "Repack DAT". If for example you repack pl3000.dat, it will
be placed in `...\Metal Gear Rising Revengeance\GameData\pl\pl3000.dat`.

### Manually select file location

If you haven't set the "Data export path" in settings, clicking "Repack DAT" will open a file dialog where you can select the folder to save the repacked DAT.
For the next export, you can choose "Repack DAT to last location" to export to the same file again.

### Overwrite original

Pressing "Repack DAT (overwrite)" will overwrite the original DAT file.

## Adding or removing files

![change packed files](assets/help/img/dat_change_packed_files.png)

To add or remove files from a DAT, right click on the DAT and select "Change packed files". In the dialog you can check which files should be included in the repacked DAT.
This will list all files inside the extracted folder. If you want to add new files, place them in the extracted folder and they will be listed here.
When done, click "Save" or "Save and export" to also repack the DAT.

The benefit of not automatically including all files in a folder is that you can store backups or different versions of files in the extracted folder without them being included in the repacked DAT.

Note: To change the the included files without F-SERVO, edit `dat_info.json` in the extracted folder.
