import 'package:flutter/material.dart';
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

  /// Creates a credential entry in the test database using Drift's generated
  /// insert method, which ensures column names match the schema.
  Future<void> createEntry({
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
      child: const MaterialApp(
        home: EntryDetailView(entryId: testEntryId),
      ),
    );
  }

  /// Helper to pump and settle async providers.
  Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('T-16: EntryDetailView reveal dialog tests', () {
    testWidgets('should_show_reveal_secret_button_when_requires_auth',
        (tester) async {
      await createEntry(
        requiresAuth: true,
        encryptedSecret: 'dummy_ciphertext',
        cipherNonce: 'dummy_nonce',
        cipherTag: 'dummy_tag',
      );

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      expect(find.text('Revelar Secreto'), findsOneWidget);
    });

    testWidgets('should_not_show_reveal_button_when_not_requires_auth',
        (tester) async {
      await createEntry(requiresAuth: false);

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      expect(find.text('Reveal Secret'), findsNothing);
    });

    testWidgets('should_show_entry_title_and_fields', (tester) async {
      await createEntry(
        requiresAuth: true,
        encryptedSecret: 'dummy',
        cipherNonce: 'dummy',
        cipherTag: 'dummy',
      );

      await tester.pumpWidget(createTestApp());
      await pumpAndSettle(tester);

      // Title should be visible
      expect(find.text('Test Service'), findsOneWidget);
      // Password field should be present
      expect(find.text('Contraseña'), findsOneWidget);
    });
  });

  group('T-17: EntryDetailView palette picker tests', () {
    /// Creates a note entry with a tag for palette picker testing.
    Future<void> createEntryWithTag({String tag = 'urgente'}) async {
      final now = DateTime.now();
      await database.into(database.entries).insert(
        Entry(
          id: testEntryId,
          type: 'NOTA',
          title: 'Test Note',
          content: 'Content with a tag',
          metadata: '{}',
          tags: '["$tag"]',
          requiresAuth: false,
          createdAt: now,
          updatedAt: now,
          version: 1,
        ),
      );
    }

    testWidgets('should_show_palette_picker_on_tag_long_press',
        (tester) async {
      await createEntryWithTag();

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
}
