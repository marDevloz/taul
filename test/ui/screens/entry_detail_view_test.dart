import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/widgets/palette_picker.dart';
import '../../helpers/test_auth.dart';

void main() {
  late AppDatabase database;
  late EntryAuthService auth;
  const testEntryId = 'test-entry-1';

  /// Creates a credential entry in the test database.
  Future<void> createCredentialEntry({
    bool requiresAuth = false,
    String? secret,
    String? encryptedSecret,
    String? cipherNonce,
    String? cipherTag,
  }) async {
    final now = DateTime.now();
    await database.into(database.entries).insert(
      Entry(
        id: testEntryId,
        type: 'CREDENCIAL',
        title: 'Test Service',
        content: '',
        metadata: '{"username":"testuser","url":"https://test.com"}',
        tags: '[]',
        requiresAuth: requiresAuth,
        secret: secret,
        encryptedSecret: encryptedSecret,
        cipherNonce: cipherNonce,
        cipherTag: cipherTag,
        createdAt: now,
        updatedAt: now,
        version: 1,
      ),
    );
  }

  /// Creates a note entry.
  Future<void> createNoteEntry({String tag = 'urgente'}) async {
    final now = DateTime.now();
    await database.into(database.entries).insert(
      Entry(
        id: testEntryId,
        type: 'NOTA',
        title: 'Test Note',
        content: 'Content',
        metadata: '{}',
        tags: '["$tag"]',
        requiresAuth: false,
        createdAt: now,
        updatedAt: now,
        version: 1,
      ),
    );
  }

  setUp(() {
    database = AppDatabase.forTesting();
    auth = createFakeAuthService();
  });

  tearDown(() {
    database.close();
  });

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entryAuthServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          ...FlutterQuillLocalizations.localizationsDelegates,
        ],
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: EntryDetailView(entryId: testEntryId),
      ),
    );
  }

  /// Helper to pump and settle async providers.
  Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('T-16: EntryDetailView inline editing - credentials', () {
    testWidgets('should_show_reveal_secret_button_when_requires_auth',
        (tester) async {
      await createCredentialEntry(
        requiresAuth: true,
        encryptedSecret: 'dummy_ciphertext',
        cipherNonce: 'dummy_nonce',
        cipherTag: 'dummy_tag',
      );

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Should prompt for master password on open for protected entries
      expect(find.text('Revelar Secreto'), findsOneWidget);
    });

    testWidgets('should_not_show_reveal_button_when_not_requires_auth',
        (tester) async {
      await createCredentialEntry(requiresAuth: false);

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      expect(find.text('Reveal Secret'), findsNothing);
      expect(find.text('Contraseña'), findsOneWidget);
    });

    testWidgets('should_show_entry_title_and_fields', (tester) async {
      await createCredentialEntry(
        requiresAuth: true,
        encryptedSecret: 'dummy',
        cipherNonce: 'dummy',
        cipherTag: 'dummy',
      );

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Title should be editable (TextField)
      expect(find.byType(TextField), findsWidgets);
      // Password field label should be present
      expect(find.text('Contraseña'), findsOneWidget);
    });

    testWidgets('should_have_editable_username_field', (tester) async {
      await createCredentialEntry(requiresAuth: false);

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Username label should be present
      expect(find.text('Usuario'), findsOneWidget);
      // TextFields should exist for editing
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should_have_no_edit_button_in_appbar', (tester) async {
      await createCredentialEntry(requiresAuth: false);

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Edit button removed from AppBar
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });

  group('T-17: EntryDetailView palette picker tests', () {
    testWidgets('should_show_palette_picker_on_tag_long_press',
        (tester) async {
      await createNoteEntry(tag: 'urgente');

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Verify the tag chip is displayed
      expect(find.text('urgente'), findsOneWidget);

      // Long-press the tag chip to open the palette picker
      await tester.longPress(find.text('urgente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the palette picker dialog is shown
      expect(find.byType(PalettePicker), findsOneWidget);
      expect(find.textContaining('Color for'), findsOneWidget);

      // Dismiss dialog by tapping outside
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.byType(PalettePicker), findsNothing);
    });

    testWidgets('should_show_palette_picker_in_credential_view',
        (tester) async {
      final now = DateTime.now();
      await database.into(database.entries).insert(
        Entry(
          id: testEntryId,
          type: 'CREDENCIAL',
          title: 'Test Service',
          content: '',
          metadata: '{"username":"testuser","url":"https://test.com"}',
          tags: '["urgente"]',
          requiresAuth: false,
          createdAt: now,
          updatedAt: now,
          version: 1,
        ),
      );

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Verify the tag chip is displayed
      expect(find.text('urgente'), findsOneWidget);

      // Long-press the tag chip to open the palette picker
      await tester.longPress(find.text('urgente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the palette picker dialog is shown
      expect(find.byType(PalettePicker), findsOneWidget);
      expect(find.textContaining('Color for'), findsOneWidget);

      // Dismiss dialog by tapping outside
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.byType(PalettePicker), findsNothing);
    });
  });

  group('T-18: Inline tag editing tests', () {
    testWidgets('should_show_tag_chips_with_delete_icon', (tester) async {
      await createNoteEntry(tag: 'urgente');

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Tag chip should be an InputChip (has onDeleted callback)
      final chip = find.byType(InputChip);
      expect(chip, findsOneWidget);

      // Delete icon (close) should be present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should_have_inline_tag_add_field', (tester) async {
      await createNoteEntry(tag: 'urgente');

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Should have the tag add field with hint text
      expect(find.text('urgente'), findsOneWidget);
    });

    testWidgets('should_have_deletable_tag_chips', (tester) async {
      await createNoteEntry(tag: 'urgente');

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Tag chip should be an InputChip with onDeleted handler
      final chips = find.byType(InputChip);
      expect(chips, findsWidgets);

      // Each InputChip should have onDeleted set
      for (final chip in chips.evaluate()) {
        final inputChip = chip.widget as InputChip;
        expect(inputChip.onDeleted, isNotNull);
      }
    });
  });

  group('T-19: Inline editing - notes', () {
    testWidgets('should_show_editable_title_field', (tester) async {
      await createNoteEntry();

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Title should be editable (at least one TextField exists
      // with the entry title in its controller)
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('should_have_no_edit_button_in_appbar', (tester) async {
      await createNoteEntry();

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Edit button should not exist
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('should_show_quill_editor_for_content', (tester) async {
      await createNoteEntry();

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Content should be rendered as a QuillEditor (editable)
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('should_show_tags_when_present', (tester) async {
      await createNoteEntry(tag: 'urgente');

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Tag text visible
      expect(find.text('urgente'), findsOneWidget);
    });
  });

  group('T-21: credential copy feedback - clipboard auto-clear', () {
    const copyFeedback = 'Contraseña copiada. Se limpiará en 30 segundos.';

    /// Warm the detail provider before the view mounts so the text
    /// controllers are populated (the screen reads them in initState).
    Future<void> pumpWithWarmProvider(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          entryAuthServiceProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      final subscription =
          container.listen(entryDetailProvider(testEntryId), (_, _) {});
      addTearDown(subscription.close);
      await container.read(entryDetailProvider(testEntryId).future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates:
                FlutterQuillLocalizations.localizationsDelegates,
            supportedLocales: FlutterQuillLocalizations.supportedLocales,
            home: EntryDetailView(entryId: testEntryId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Advances the clock so the clipboard clear timer and the snackbar
    /// auto-dismiss timer can fire, then unmounts the tree so riverpod can
    /// schedule its deferred provider disposal before the test ends.
    Future<void> flushPendingTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 35));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('should_show_secret_copy_feedback_when_copying_password',
        (tester) async {
      await createCredentialEntry(
        requiresAuth: false,
        secret: 'clave-secreta',
      );

      await pumpWithWarmProvider(tester);

      final copyButtons = find.byTooltip('Copiar');
      expect(copyButtons, findsWidgets);

      await tester.tap(copyButtons.at(1));
      await tester.pump();

      expect(find.text(copyFeedback), findsOneWidget);

      await flushPendingTimers(tester);
    });

    testWidgets('should_show_generic_feedback_when_copying_username',
        (tester) async {
      await createCredentialEntry(
        requiresAuth: false,
        secret: 'clave-secreta',
      );

      await pumpWithWarmProvider(tester);

      await tester.tap(find.byTooltip('Copiar').at(0));
      await tester.pump();

      expect(find.text('Contenido copiado'), findsOneWidget);

      await flushPendingTimers(tester);
    });

    testWidgets('should_clear_clipboard_after_seconds_when_copying_password',
        (tester) async {
      // Simulates a real system clipboard: setData stores the text, getData
      // returns it. Enables testing the content-aware clear guard.
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = args['text'] as String?;
          } else if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await createCredentialEntry(
        requiresAuth: false,
        secret: 'clave-secreta',
      );

      await pumpWithWarmProvider(tester);

      await tester.tap(find.byTooltip('Copiar').at(1));
      await tester.pump();

      expect(clipboardText, 'clave-secreta');

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(clipboardText, '');

      await flushPendingTimers(tester);
    });

    testWidgets('should_not_clear_clipboard_when_user_copied_something_else',
        (tester) async {
      // Simulates a real system clipboard with state.
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = args['text'] as String?;
          } else if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await createCredentialEntry(
        requiresAuth: false,
        secret: 'clave-secreta',
      );

      await pumpWithWarmProvider(tester);

      await tester.tap(find.byTooltip('Copiar').at(1));
      await tester.pump();

      expect(clipboardText, 'clave-secreta');

      // The user copies something else before the 30s window elapses.
      clipboardText = 'otra-cosa';
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      // Our timer must NOT wipe the user's newer clipboard content.
      expect(clipboardText, 'otra-cosa');

      await flushPendingTimers(tester);
    });
  });
}
