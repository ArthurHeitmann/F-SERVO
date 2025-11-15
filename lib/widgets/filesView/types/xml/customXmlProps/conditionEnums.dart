enum ConditionType {
  defaultHapState(
    displayName: "Hap State",
    description:
        "Checks the current state of this PUID referenced action target.",
  ),
  eventState(
    displayName: "Event State",
    description:
        "Checks if the global event of the PUID referenced target has occurred.",
  ),
  functionCall(
    displayName: "Function Call",
    description:
        "Calls a function by name <label> that exists on the PUID referenced target with the <args> (parameter) , compairs its result on <value>.",
  ),
  postSignal(
    displayName: "Post Signal",
    description:
        "Ensures a static signal also exists dynamically. (This is unused.).",
  ),
  entityLayoutState(
    displayName: "Entity State",
    description:
        "Checks the current state of an EntityLayout PUID referenced target.",
  );

  const ConditionType({
    required this.displayName,
    required this.description,
  });

  final String displayName;
  final String description;
}

enum ConditionPredicate {
  equal(displayName: "Value == Result"),
  notEqual(displayName: "Value != Result"),
  lessThan(displayName: "Value < Result"),
  lessOrEqual(displayName: "Value <= Result"),
  greaterThan(displayName: "Value > Result"),
  greaterOrEqual(displayName: "Value >= Result"),
  exists(displayName: "Value exist"),
  notExists(displayName: "Value !exist");

  const ConditionPredicate({required this.displayName});
  final String displayName;
}