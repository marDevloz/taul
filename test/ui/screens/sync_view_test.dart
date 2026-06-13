import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/sync_providers.dart';
import 'package:taul/ui/screens/sync_view.dart';

/// Common overrides needed by all SyncView tests.
List<Override> _syncViewOverrides(AppLockStatus lockStatus) => [
  appLockProvider.overrideWith((ref) => AppLockNotifier(ref)
    ..state = lockStatus),
  deviceIdProvider.overrideWith((ref) async => 'test-device'),
  syncStateProvider.overrideWith((ref) => SyncState.idle),
  conflictCountProvider.overrideWith((ref) => Stream.value(0)),
  syncPortProvider.overrideWith((ref) => null),
  syncPairingCodeProvider.overrideWith((ref) => null),
  syncPairingServiceProvider.overrideWith((ref) => null),
  startSyncProvider.overrideWith((ref) => () async {}),
  stopSyncProvider.overrideWith((ref) => () async {}),
];

void main() {
  group('SyncView', () {
    testWidgets('renders title and start button when unlocked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _syncViewOverrides(AppLockStatus.unlocked),
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
          overrides: _syncViewOverrides(AppLockStatus.locked),
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
