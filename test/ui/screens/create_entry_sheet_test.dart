import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/create_entry_sheet.dart';

/// Fake repository that never touches the DB.
class _FakeEntryRepository implements IEntryRepository {
  @override
  Future<Entry> create(Entry entry) async => entry;

  @override
  Future<Entry> getById(String id) async => _entry(id: id);

  @override
  Future<List<Entry>> list({
    EntryType? type,
    bool includeDeleted = false,
    bool excludeArchived = false,
  }) async => [];

  @override
  Future<List<Entry>> search(String query, {int limit = 100}) async => [];

  @override
  Future<Entry> update(Entry entry) async => entry;

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<void> hardDelete(String id) async {}
}

Entry _entry({required String id}) {
  return Entry(
    id: id,
    type: EntryType.note,
    title: 'Test',
    content: 'Content',
    metadata: const {},
    tags: const [],
    tagsColors: const {},
    requiresAuth: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates:
          FlutterQuillLocalizations.localizationsDelegates,
      home: const Scaffold(
        body: SizedBox(
          height: 600,
          child: CreateEntrySheet(),
        ),
      ),
    ),
  );
}

void main() {
  group('CreateEntrySheet — draft restoration', () {
    testWidgets(
        'should restore draft title and tags on open when draft exists',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          entryRepositoryProvider.overrideWith((ref) => _FakeEntryRepository()),
          entryListProvider.overrideWith((ref) async => []),
          tagSettingsListProvider.overrideWith((ref) async => []),
          entryDraftProvider.overrideWith((ref) {
            final notifier = EntryDraftNotifier();
            notifier.save(EntryDraft(
              title: 'Restored Title',
              content: '{"ops":[{"insert":"Hello"}]}',
              tags: 'draft, test',
              manualType: EntryType.note,
            ));
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();
      // Suppress warnings from Quill rendering overflow at teardown
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Restored Title'), findsOneWidget);
      expect(find.text('draft, test'), findsOneWidget);
    });

    testWidgets('should show empty fields when no draft exists',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          entryRepositoryProvider.overrideWith((ref) => _FakeEntryRepository()),
          entryListProvider.overrideWith((ref) async => []),
          tagSettingsListProvider.overrideWith((ref) async => []),
          entryDraftProvider.overrideWith((ref) => EntryDraftNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Draft title should NOT exist
      expect(find.text('Restored Title'), findsNothing);
    });
  });
}
