
import 'package:flutter/material.dart';

import '../../stateManagement/sync/syncObjects.dart';

class SyncButton extends StatefulWidget {
  final String uuid;
  final SyncedObject Function() makeSyncedObject;
  
  const SyncButton({ super.key, required this.uuid, required this.makeSyncedObject });

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
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
    if (!_isSynced) {
      return IconButton(
        icon: const Icon(Icons.sync, size: 20),
        splashRadius: 20,
        onPressed: () => startSyncingObject(widget.makeSyncedObject()),
      );
    }
    return IconButton(   // TODO
      icon: const Icon(Icons.sync_disabled, size: 20),
      splashRadius: 20,
      onPressed: () => syncedObjects[widget.uuid]?.endSync(),
    );
  }
}
