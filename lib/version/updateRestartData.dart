
class UpdateRestartData {
  final List<String> openedFiles;
  final List<String> openedHierarchyFiles;
  
  const UpdateRestartData(this.openedFiles, this.openedHierarchyFiles);

  Map toJson() => {
    "openedFiles": openedFiles,
    "openedHierarchyFiles": openedHierarchyFiles,
  };

  factory UpdateRestartData.fromJson(Map<String, dynamic> json) {
    return UpdateRestartData(
      List<String>.from(json["openedFiles"]),
      List<String>.from(json["openedHierarchyFiles"]),
    );
  }
}
