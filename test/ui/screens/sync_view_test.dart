import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/sync_view.dart';

void main() {
  group('SyncView', () {
    testWidgets('renders title and start button when unlocked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockProvider.overrideWith((ref) => AppLockNotifier(ref)
              ..state = AppLockStatus.unlocked),
          ],
          child: const MaterialApp(home: SyncView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sincronización'), findsOneWidget);
      expect(find.text('Iniciar sincronización'), findsOneWidget);
    });

    testWidgets('shows locked message when vault is locked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockProvider.overrideWith((ref) => AppLockNotifier(ref)
              ..state = AppLockStatus.locked),
          ],
          child: const MaterialApp(home: SyncView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Desbloqueá el vault para sincronizar'),
        findsOneWidget,
      );
    });
  });
}
