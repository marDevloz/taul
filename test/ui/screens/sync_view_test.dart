import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/sync_providers.dart';
import 'package:taul/ui/screens/sync_connect_sheet.dart';
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

    testWidgets(
      'shows connect card when sync state is idle',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Conectar a dispositivo'), findsOneWidget);
        expect(find.byIcon(Icons.link), findsOneWidget);
      },
    );

    testWidgets(
      'shows connect card when sync state is complete',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.complete),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Conectar a dispositivo'), findsOneWidget);
      },
    );

    testWidgets(
      'hides connect card when sync state is syncing',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.syncing),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Conectar a dispositivo'), findsNothing);
      },
    );

    testWidgets(
      'shows result card with entries and conflicts when complete',
      (tester) async {
        // Override the result provider with a completed result
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.complete),
              lastSyncResultProvider.overrideWith(
                (ref) => const ProcessSyncResult(
                  entriesUpserted: 10,
                  conflictsCount: 2,
                ),
              ),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('10 entradas sincronizadas, 2 conflictos'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows resolver conflictos button when conflicts exist',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.complete),
              lastSyncResultProvider.overrideWith(
                (ref) => const ProcessSyncResult(
                  entriesUpserted: 5,
                  conflictsCount: 3,
                ),
              ),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Resolver conflictos'), findsOneWidget);
      },
    );

    testWidgets(
      'hides resolver conflictos button when no conflicts',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.complete),
              lastSyncResultProvider.overrideWith(
                (ref) => const ProcessSyncResult(
                  entriesUpserted: 7,
                  conflictsCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Resolver conflictos'), findsNothing);
      },
    );

    testWidgets(
      'shows no-conflicts message when zero conflicts',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._syncViewOverrides(AppLockStatus.unlocked),
              syncStateProvider.overrideWith((ref) => SyncState.complete),
              lastSyncResultProvider.overrideWith(
                (ref) => const ProcessSyncResult(
                  entriesUpserted: 7,
                  conflictsCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(home: SyncView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('7 entradas sincronizadas, sin conflictos'),
          findsOneWidget,
        );
      },
    );
  });

  group('SyncConnectSheet', () {
    testWidgets(
      'renders URL field, pairing code field, and Conectar button',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // URL field should be present with https:// prefix
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('https://'), findsOneWidget);

        // Pairing code field hint
        expect(find.text('Código de 6 dígitos'), findsOneWidget);

        // Conectar button should be present
        expect(find.text('Conectar'), findsOneWidget);
      },
    );

    testWidgets(
      'Conectar button is disabled when pairing code is empty',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter a valid URL
        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://192.168.1.100:54321');
        await tester.pumpAndSettle();

        // Button should be disabled (empty pairing code)
        final button = find.byType(FilledButton);
        expect(button, findsOneWidget);
        final filledButton =
            button.evaluate().first.widget as FilledButton;
        expect(filledButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Conectar button is disabled when pairing code is not 6 digits',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter valid URL
        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://192.168.1.100:54321');

        // Enter invalid code (not 6 digits)
        final codeField = find.byType(TextField).last;
        await tester.enterText(codeField, '1234');
        await tester.pumpAndSettle();

        // Button should be disabled
        final button = find.byType(FilledButton);
        final filledButton =
            button.evaluate().first.widget as FilledButton;
        expect(filledButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Conectar button is enabled when URL and 6-digit code are valid',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter valid URL
        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://192.168.1.100:54321');

        // Enter valid 6-digit code
        final codeField = find.byType(TextField).last;
        await tester.enterText(codeField, '123456');
        await tester.pumpAndSettle();

        // Button should be enabled
        final button = find.byType(FilledButton);
        final filledButton =
            button.evaluate().first.widget as FilledButton;
        expect(filledButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Conectar button is disabled when URL is only https://',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // URL field starts with https:// but no host
        // Enter valid 6-digit code
        final codeField = find.byType(TextField).last;
        await tester.enterText(codeField, '123456');
        await tester.pumpAndSettle();

        // Button should be disabled (URL is just https://)
        final button = find.byType(FilledButton);
        final filledButton =
            button.evaluate().first.widget as FilledButton;
        expect(filledButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Conectar button is disabled when code contains letters',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => SyncState.idle),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SyncConnectSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter valid URL
        final urlField = find.byType(TextField).first;
        await tester.enterText(urlField, 'https://192.168.1.100:54321');

        // Enter code with letters (6 chars but not all digits)
        final codeField = find.byType(TextField).last;
        await tester.enterText(codeField, '12ab34');
        await tester.pumpAndSettle();

        // Button should be disabled
        final button = find.byType(FilledButton);
        final filledButton =
            button.evaluate().first.widget as FilledButton;
        expect(filledButton.onPressed, isNull);
      },
    );
  });
}
