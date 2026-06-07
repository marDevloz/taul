import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';

void main() {
  group('EntryDraftNotifier', () {
    test('should_be_null_when_no_draft', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(entryDraftProvider), isNull);
    });

    test('should_set_state_when_save_called', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draft = EntryDraft(
        title: 'Test Title',
        content: '{"ops":[{"insert":"Hello"}]}',
        tags: 'test, draft',
        manualType: EntryType.note,
      );

      container.read(entryDraftProvider.notifier).save(draft);

      final saved = container.read(entryDraftProvider);
      expect(saved, isNotNull);
      expect(saved!.title, 'Test Title');
      expect(saved.content, '{"ops":[{"insert":"Hello"}]}');
      expect(saved.tags, 'test, draft');
      expect(saved.manualType, EntryType.note);
    });

    test('should_overwrite_previous_draft_when_save_called_twice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(entryDraftProvider.notifier).save(EntryDraft(
        title: 'First',
        content: '',
        tags: '',
      ));
      container.read(entryDraftProvider.notifier).save(EntryDraft(
        title: 'Second',
        content: '',
        tags: '',
      ));

      final saved = container.read(entryDraftProvider);
      expect(saved!.title, 'Second');
    });

    test('should_reflect_saved_draft_when_read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // No draft yet
      expect(container.read(entryDraftProvider), isNull);

      final draft = EntryDraft(
        title: 'Draft',
        content: 'content',
        tags: 'tag',
      );
      container.read(entryDraftProvider.notifier).save(draft);

      expect(container.read(entryDraftProvider), draft);
    });

    test('should_be_null_when_clear_called', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(entryDraftProvider.notifier).save(EntryDraft(
        title: 'To Clear',
        content: '',
        tags: '',
      ));
      expect(container.read(entryDraftProvider), isNotNull);

      container.read(entryDraftProvider.notifier).clear();

      expect(container.read(entryDraftProvider), isNull);
    });

    test('should_allow_null_when_manual_type_is_null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(entryDraftProvider.notifier).save(EntryDraft(
        title: 'No Type',
        content: '',
        tags: '',
        manualType: null,
      ));

      final saved = container.read(entryDraftProvider);
      expect(saved!.manualType, isNull);
      expect(saved.title, 'No Type');
    });
  });
}