
import 'package:flutter/material.dart';

import 'ChangeNotifierWidget.dart';
import '../../stateManagement/sync/syncObjects.dart';
import '../../stateManagement/sync/syncServer.dart';
import 'onHoverBuilder.dart';

class SyncButton extends ChangeNotifierWidget {
  final String uuid;
  final SyncedObject Function() makeSyncedObject;
  
  SyncButton({ super.key, required this.uuid, required this.makeSyncedObject }) : super(notifier: canSync);

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ChangeNotifierState<SyncButton> {
  bool _isSynced = false;

  @override
  void initState() {
    syncedObjectsNotifier.addListener(_onSyncedObjectsChanged);
    _isSynced = syncedObjects.containsKey(widget.uuid);
    super.initState();
  }

  @override
  void dispose() {
    syncedObjectsNotifier.removeListener(_onSyncedObjectsChanged);
    super.dispose();
  }

  void _onSyncedObjectsChanged() {
    bool isSynced = syncedObjects.containsKey(widget.uuid);
    if (isSynced != _isSynced) {
      _isSynced = isSynced;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnHoverBuilder(
      builder: (cxt, isHovering) => _makeButton(isHovering),
    );
  }

  Widget _makeButton(bool isHovering) {
    if (!canSync.value) {
      return Tooltip(
        message: "No connection to Blender",
        waitDuration: const Duration(milliseconds: 750),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isHovering ? 1 : 0,
          child: const IconButton(
            icon: Icon(Icons.sync_disabled),
            onPressed: null,
          ),
        ),
      );
    }
    if (!_isSynced) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isHovering ? 1 : 0.5,
        child: IconButton(
          icon: const Icon(Icons.sync, size: 20),
          splashRadius: 20,
          onPressed: () => startSyncingObject(widget.makeSyncedObject()),
        ),
      );
    }
    return IconButton(
      icon: isHovering ? const Icon(Icons.sync_disabled, size: 20) : const Icon(Icons.sync_alt, size: 20),
      splashRadius: 20,
      onPressed: () => syncedObjects[widget.uuid]?.endSync(),
    );
  }
}
