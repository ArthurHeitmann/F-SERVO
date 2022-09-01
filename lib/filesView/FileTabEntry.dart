import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/filesView/openFilesManager.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';


class FileTabEntry extends StatelessWidget {
  final OpenFileData file;
  final FilesAreaManager area;
  
  const FileTabEntry({Key? key, required this.file, required this.area}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => area.currentFile = file,
      child: SizedBox(
        width: 150,
        child: Material(
          color: file == area.currentFile ? Color.fromARGB(255, 36, 36, 36) : Color.fromARGB(255, 59, 59, 59),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child:
                  Text(
                    file.name,
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.close),
                  onPressed: () => area.closeFile(file),
                  iconSize: 15,
                  splashRadius: 15,
                  color: Color.fromRGBO(255, 255, 255, 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
