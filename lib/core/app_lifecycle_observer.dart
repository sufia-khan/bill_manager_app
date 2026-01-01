import 'package:flutter/widgets.dart';
import '../services/smart_sync_service.dart';

/// App Lifecycle Observer
///
/// Monitors app lifecycle events to trigger sync at appropriate times:
/// - App paused/backgrounded: Trigger immediate sync
/// - App resumed: Resume any failed syncs
class AppLifecycleObserver extends WidgetsBindingObserver {
  final SmartSyncService _syncService;

  AppLifecycleObserver(this._syncService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background - sync immediately
        _syncService.syncOnPause();
        break;

      case AppLifecycleState.resumed:
        // App came back - schedule sync after short delay
        Future.delayed(const Duration(seconds: 2), () {
          _syncService.scheduleDebouncedSync();
        });
        break;

      default:
        break;
    }
  }
}
