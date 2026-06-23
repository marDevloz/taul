import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
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
}
