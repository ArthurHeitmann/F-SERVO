
// ignore_for_file: camel_case_types

import 'localizedString.dart';

class QuestId {
  final int id;

  const QuestId(this.id);

  @override
  String toString() {
    return "q${id.toString().padLeft(3, "0")}";
  }
}

class QuestStage {
  final String name;
  final int? id;
  final QuestId questId;

  const QuestStage(this.questId, this.name, this.id);

  String getStageName() {
    return name;
  }

  @override
  String toString() {
    return "$questId/${getStageName()}";
  }
}

class QuestStageWithIndex extends QuestStage {
  final int index;

  const QuestStageWithIndex(QuestId questId, String name, int? id, this.index) : super(questId, name, id);

  @override
  String getStageName() {
    return "${name}_$index";
  }
}

class QuestStage_RUN extends QuestStageWithIndex {
  const QuestStage_RUN(QuestId questId, int index) : super(questId, "RUN", 100, index);
}
class QuestStage_FAIL extends QuestStageWithIndex {
  const QuestStage_FAIL(QuestId questId, int index) : super(questId, "FAIL", 200, index);
}
class QuestStage_END extends QuestStageWithIndex {
  const QuestStage_END(QuestId questId, int index) : super(questId, "END", 3, index);
}
class QuestStage_REQ extends QuestStage {
  const QuestStage_REQ(QuestId questId) : super(questId, "REQ", null);
}
class QuestStage_CLR extends QuestStage {
  const QuestStage_CLR(QuestId questId) : super(questId, "CLR", 1);
}
class QuestStage_DONE extends QuestStage {
  const QuestStage_DONE(QuestId questId) : super(questId, "DONE", 2);
}
class QuestStage_DONE2 extends QuestStage {
  const QuestStage_DONE2(QuestId questId) : super(questId, "DONE", null);

  @override
  String toString() {
    return "${questId}_${getStageName()}";
  }
}
class QuestStage_FIN extends QuestStage {
  const QuestStage_FIN(QuestId questId) : super(questId, "FIN", 4);
}
class QuestStage_BREAK extends QuestStage {
  const QuestStage_BREAK(QuestId questId) : super(questId, "BREAK", null);
}

class QuestStageWithDescription {
  final QuestStage stage;
  final LocalizedString? description;

  const QuestStageWithDescription(this.stage, [this.description]);
}
