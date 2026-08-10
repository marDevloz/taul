import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart'
    hide Conflict, Entry;
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/sync_providers.dart';
import 'package:taul/ui/screens/conflict_view.dart';

Entry _entry(String title) => Entry(
  id: 'entry-1',
  type: EntryType.note,
  title: title,
  content: 'content',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('ConflictView', () {
    testWidgets('shows empty state when no conflicts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingConflictsProvider.overrideWith((_) async => <Conflict>[]),
          ],
          child: const MaterialApp(home: ConflictView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin conflictos pendientes'), findsOneWidget);
    });

    testWidgets('shows conflict cards when conflicts exist', (tester) async {
      final conflicts = [
        Conflict(
          id: 1,
          entryId: 'entry-1',
          localVersion: _entry('Local Title'),
          remoteVersion: _entry('Remote Title'),
          peerDeviceId: 'peer-device-id-12345678',
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingConflictsProvider.overrideWith((_) async => conflicts),
          ],
          child: const MaterialApp(home: ConflictView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local Title'), findsOneWidget);
      expect(find.textContaining('peer-dev'), findsOneWidget);
    });

    testWidgets('navigates to detail on tap', (tester) async {
      final conflicts = [
        Conflict(
          id: 1,
          entryId: 'entry-1',
          localVersion: _entry('Test Entry'),
          remoteVersion: _entry('Remote Entry'),
          peerDeviceId: 'peer-device-id-12345678',
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingConflictsProvider.overrideWith((_) async => conflicts),
          ],
          child: const MaterialApp(home: ConflictView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Entry'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle de conflicto'), findsOneWidget);

      // Buttons are at the bottom of a ListView — scroll to reveal them
      await tester.scrollUntilVisible(
        find.text('Mantener local'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Mantener local'), findsOneWidget);
      expect(find.text('Mantener remoto'), findsOneWidget);
      expect(find.text('Mantener ambos'), findsOneWidget);
    });

    testWidgets('should_write_remote_version_when_mantener_remoto', (
      tester,
    ) async {
      final now = DateTime(2026);
      final local = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Local Title',
        content: 'local content',
        createdAt: now,
        updatedAt: now,
        version: 1,
      );
      final remote = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Remote Title',
        content: 'remote content',
        createdAt: now,
        updatedAt: now,
        version: 2,
      );

      final database = AppDatabase.forTesting();
      addTearDown(() => database.close());
      final entryDao = EntryDao(database);
      final conflictDao = ConflictDao(database);

      await entryDao.insert(local);
      await conflictDao.insert(
        Conflict(
          id: 0,
          entryId: 'entry-1',
          localVersion: local,
          remoteVersion: remote,
          peerDeviceId: 'peer-device-id-12345678',
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: ConflictView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Local Title'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Mantener remoto'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mantener remoto'));
      await tester.pumpAndSettle();

      final stored = await entryDao.get('entry-1');
      expect(stored, isNotNull);
      expect(stored!.title, 'Remote Title');
      expect(stored.version, remote.version + 1);

      final conflictRows = await conflictDao.getByEntryId('entry-1');
      expect(conflictRows, hasLength(1));
      expect(conflictRows.single.resolution, ConflictResolution.keepRemote);
    });
  });
}
