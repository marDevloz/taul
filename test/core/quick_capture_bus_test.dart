import 'package:flutter_test/flutter_test.dart';
import 'package:taul/core/quick_capture_bus.dart';

void main() {
  group('QuickCaptureBus', () {
    test('should_increment_counter_on_trigger', () {
      final before = QuickCaptureBus.counter.value;
      QuickCaptureBus.trigger();
      expect(QuickCaptureBus.counter.value, before + 1);
    });

    test('should_notify_listeners_on_trigger', () {
      var notifications = 0;
      void listener() => notifications++;

      QuickCaptureBus.counter.addListener(listener);
      QuickCaptureBus.trigger();
      QuickCaptureBus.counter.removeListener(listener);

      expect(notifications, 1);
    });
  });
}
