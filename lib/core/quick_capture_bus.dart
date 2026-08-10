import 'package:flutter/foundation.dart';

/// App-global trigger for instant quick capture from the system tray or a
/// global hotkey. HomeView listens to this and opens the create form.
class QuickCaptureBus {
  QuickCaptureBus._();

  static final ValueNotifier<int> counter = ValueNotifier<int>(0);

  /// Fires a quick-capture request. Safe to call from tray/hotkey handlers.
  static void trigger() => counter.value++;
}
