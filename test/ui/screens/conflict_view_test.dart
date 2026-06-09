import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
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
      expect(find.textContaining('peer-device'), findsOneWidget);
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
      expect(find.text('Mantener local'), findsOneWidget);
      expect(find.text('Mantener remoto'), findsOneWidget);
      expect(find.text('Mantener ambos'), findsOneWidget);
    });
  });
}
