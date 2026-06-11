import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/usecases/create_entry.dart';
import 'package:taul/ui/controllers/create_entry_controller.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/// Converts plain text to Delta JSON string (the format the controller uses).
String _delta(String plainText) =>
    RichTextHelper.documentToJson(RichTextHelper.plainTextToDocument(plainText));

/// Mocks [CreateEntry] so we can verify [call] invocations.
class _MockCreateEntry extends Mock implements CreateEntry {
  // mocktail generates the call() method automatically.
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockCreateEntry mockCreateEntry;
  late ProviderContainer container;
  late CreateEntryController controller;

  setUp(() {
    mockCreateEntry = _MockCreateEntry();
    container = ProviderContainer(
      overrides: [
        createEntryProvider.overrideWith((ref) => mockCreateEntry),
        entryListProvider.overrideWith((ref) async => []),
      ],
    );
    controller = container.read(createEntryControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  // =========================================================================
  // Initial state
  // =========================================================================

  group('constructor', () {
    test('initial state has default values', () {
      final state = container.read(createEntryControllerProvider);
      expect(state.title, '');
      expect(state.content, '');
      expect(state.tags, '');
      expect(state.detectedType, isNull);
      expect(state.manualType, isNull);
      expect(state.isSaving, false);
      expect(state.error, isNull);
    });
  });

  // =========================================================================
  // Static helpers
  // =========================================================================

  group('splitTitle', () {
    test('extracts title from "# " marker', () {
      final result = CreateEntryController.splitTitle('Salsa# !idea');
      expect(result.title, 'Salsa');
      expect(result.rest, '!idea');
    });

    test('returns empty title when no marker', () {
      final result = CreateEntryController.splitTitle('no marker');
      expect(result.title, '');
      expect(result.rest, 'no marker');
    });

    test('handles empty string', () {
      final result = CreateEntryController.splitTitle('');
      expect(result.title, '');
      expect(result.rest, '');
    });
  });

  group('extractTags', () {
    test('delegates to RichTextHelper.extractTags', () {
      final result = CreateEntryController.extractTags('hello -#work -#urgent');
      expect(result.tags, ['work', 'urgent']);
      expect(result.clean, 'hello');
    });

    test('returns empty tags when none present', () {
      final result = CreateEntryController.extractTags('hello world');
      expect(result.tags, isEmpty);
      expect(result.clean, 'hello world');
    });

    test('handles accented tags correctly', () {
      final result = CreateEntryController.extractTags('texto -#computación -#nú');
      expect(result.tags, ['computación', 'nú']);
      expect(result.clean, 'texto');
    });

    test('handles ñ and mixed accented tags', () {
      final result = CreateEntryController.extractTags('-#desarrollo -#programación -#ñ');
      expect(result.tags, ['desarrollo', 'programación', 'ñ']);
    });
  });

  group('stripTitleAndTags', () {
    test('strips prefix and tags from Delta JSON', () {
      // Delta JSON for "Meeting# content -#work"
      final delta = _delta('Meeting# content -#work');
      final result = CreateEntryController.stripTitleAndTags(delta, ['work'], 'Meeting');
      final plain = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(result),
      ).trim();
      expect(plain, 'content');
    });

    test('returns original when prefix does not match', () {
      final delta = _delta('other content');
      final result = CreateEntryController.stripTitleAndTags(delta, [], 'Meeting');
      expect(result, delta);
    });
  });

  // =========================================================================
  // detectTypeFromContent
  // =========================================================================

  group('detectTypeFromContent', () {
    test('detects idea from leading "!"', () {
      controller.detectTypeFromContent(_delta('!ideaGenial'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.idea);
    });

    test('detects task from "[]" marker', () {
      controller.detectTypeFromContent(_delta('[] do this'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.task);
    });

    test('detects credential from "***" pattern', () {
      controller.detectTypeFromContent(_delta('serv*user*pass'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.credential);
    });

    test('detects glossary from "word:" pattern', () {
      controller.detectTypeFromContent(_delta('term:definition'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.glossary);
    });

    test('detects note as fallback', () {
      controller.detectTypeFromContent(_delta('plain text content'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.note);
    });

    test('sets detectedType to null on empty content', () {
      controller.detectTypeFromContent('');
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, isNull);
    });

    test('recovers gracefully from invalid Delta JSON', () {
      // [{}] passes isRichText but Document.fromJson throws — getDocument
      // falls back to plain text, and detectTypeFromContent recovers silently
      controller.detectTypeFromContent('[{}]');
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, isNotNull); // recovered, didn't crash
    });

    test('detects idea from "!" at the start of content (before Title#)', () {
      // The `!` check happens on the FULL plain text, not after Title# split.
      // Only content that starts with `!` (and not `! `) is an idea.
      controller.detectTypeFromContent(_delta('!idea'));
      final state = container.read(createEntryControllerProvider);
      expect(state.detectedType, EntryType.idea);
    });

    test('updates content in state', () {
      final delta = _delta('hello world');
      controller.detectTypeFromContent(delta);
      final state = container.read(createEntryControllerProvider);
      expect(state.content, delta);
    });
  });

  // =========================================================================
  // processContentForType
  // =========================================================================

  group('processContentForType', () {
    test('idea strips leading "!"', () {
      final result = controller.processContentForType(
        EntryType.idea, '!idea', '', []);
      expect(result.content.content, 'idea');
      expect(result.type, EntryType.idea);
    });

    test('idea keeps body unchanged when no "!"', () {
      final result = controller.processContentForType(
        EntryType.idea, 'just text', '', []);
      expect(result.content.content, 'just text');
    });

    test('glossary calls formatForGlossary', () {
      final body = 'term: definition';
      final result = controller.processContentForType(
        EntryType.glossary, body, '', []);
      expect(result.type, EntryType.glossary);
      // formatForGlossary capitalizes term + definition and bolds/italicizes
      final plain = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(result.content.content),
      ).trim();
      expect(plain, contains('Term'));
      expect(plain, contains('Definition'));
    });

    test('credential returns structured content with secret', () {
      final body = 'serv*user*pass';
      final result = controller.processContentForType(
        EntryType.credential, body, '', []);
      expect(result.type, EntryType.credential);
      expect(result.content.content, contains('Usuario:'));
      expect(result.content.secret, 'pass');
      expect(result.content.requiresAuth, true);
    });

    test('credential parse failure falls back to note', () {
      // No asterisks → CredentialParser returns null
      final body = 'just plain text';
      final result = controller.processContentForType(
        EntryType.credential, body, '', []);
      expect(result.type, EntryType.note);
      expect(result.content.secret, isNull);
      expect(result.content.requiresAuth, false);
    });

    test('task strips content via stripTitleAndTags', () {
      // In save(), body is plain text after extractTags + splitTitle:
      // "[] Meeting# task -#work" → extractTags → "[] Meeting# task", tags: [work]
      //                           → splitTitle → title: "Meeting", rest: "[] task"
      final body = '[] task';
      final result = controller.processContentForType(
        EntryType.task, body, 'Meeting', ['work']);
      expect(result.type, EntryType.task);
      expect(result.content.tags, ['work']);
      final plain = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(result.content.content),
      ).trim();
      // Title prefix and tags already stripped by save() before calling;
      // task marker "[] " is stripped inside processContentForType
      expect(plain, 'task');
    });

    test('note strips content via stripTitleAndTags', () {
      final body = _delta('Meeting# plain note -#tag1');
      final result = controller.processContentForType(
        EntryType.note, body, 'Meeting', ['tag1']);
      expect(result.type, EntryType.note);
      expect(result.content.secret, isNull);
      final plain = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(result.content.content),
      ).trim();
      expect(plain, 'plain note');
    });
  });

  // =========================================================================
  // Lifecycle helpers
  // =========================================================================

  group('setManualType', () {
    test('sets manualType and isManual becomes true', () {
      controller.setManualType(EntryType.task);
      final state = container.read(createEntryControllerProvider);
      expect(state.manualType, EntryType.task);
      expect(state.isManual, true);
    });

    test('setting to null reverts to auto detection', () {
      controller.setManualType(EntryType.task);
      controller.setManualType(null);
      final state = container.read(createEntryControllerProvider);
      expect(state.manualType, isNull);
      expect(state.isManual, false);
    });
  });

  group('loadDraft', () {
    test('populates state from draft', () {
      controller.loadDraft(EntryDraft(
        title: 'Draft Title',
        content: _delta('draft content'),
        tags: 'draft,test',
        manualType: EntryType.note,
      ));
      final state = container.read(createEntryControllerProvider);
      expect(state.title, 'Draft Title');
      expect(state.content, _delta('draft content'));
      expect(state.tags, 'draft,test');
      expect(state.manualType, EntryType.note);
    });
  });

  group('reset', () {
    test('resets all fields to defaults', () {
      // Mutate state first
      controller.detectTypeFromContent(_delta('hello'));
      controller.setManualType(EntryType.task);
      controller.state = controller.state.copyWith(
        title: 'Test',
        tags: 'a,b',
      );

      controller.reset();
      final state = container.read(createEntryControllerProvider);
      expect(state.title, '');
      expect(state.content, '');
      expect(state.tags, '');
      expect(state.detectedType, isNull);
      expect(state.manualType, isNull);
      expect(state.isSaving, false);
      expect(state.error, isNull);
    });
  });

  // =========================================================================
  // save() — full save orchestration
  // =========================================================================

  group('save', () {
    setUp(() {
      when(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: any(named: 'type'),
        secret: any(named: 'secret'),
        requiresAuth: any(named: 'requiresAuth'),
        metadata: any(named: 'metadata'),
        tags: any(named: 'tags'),
      )).thenAnswer((_) async => _entry(id: 'new-entry'));
    });

    test('calls createEntry with correct params', () async {
      controller.detectTypeFromContent(_delta('[] buy milk -#home'));
      expect(container.read(createEntryControllerProvider).detectedType, EntryType.task);

      final saved = await controller.save();
      expect(saved, true);

      verify(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: EntryType.task,
        secret: any(named: 'secret', that: isNull),
        requiresAuth: false,
        metadata: any(named: 'metadata'),
        tags: ['home'],
      )).called(1);
    });

    test('returns false when both content and title are empty', () async {
      final saved = await controller.save();
      expect(saved, false);
      verifyNever(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: any(named: 'type'),
      ));
    });

    test('sets error and isSaving=false on exception', () async {
      when(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: any(named: 'type'),
        secret: any(named: 'secret'),
        requiresAuth: any(named: 'requiresAuth'),
        metadata: any(named: 'metadata'),
        tags: any(named: 'tags'),
      )).thenThrow(Exception('DB error'));

      controller.detectTypeFromContent(_delta('hello world'));
      expect(container.read(createEntryControllerProvider).isSaving, false);

      expect(() => controller.save(), throwsA(isA<Exception>()));
      final state = container.read(createEntryControllerProvider);
      expect(state.isSaving, false);
      expect(state.error, contains('DB error'));
    });

    test('manual title overrides parsed title', () async {
      controller.detectTypeFromContent(_delta('Parsed# content'));
      controller.setTitle('Manual Title');

      await controller.save();
      verify(() => mockCreateEntry(
        title: 'Manual Title',
        content: any(named: 'content'),
        type: any(named: 'type'),
        secret: any(named: 'secret'),
        requiresAuth: any(named: 'requiresAuth'),
        metadata: any(named: 'metadata'),
        tags: any(named: 'tags'),
      )).called(1);
    });

    test('merges manual and extracted tags without duplicates', () async {
      controller.detectTypeFromContent(_delta('content -#work'));
      controller.setTags('urgent, work');

      await controller.save();
      verify(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: any(named: 'type'),
        secret: any(named: 'secret'),
        requiresAuth: any(named: 'requiresAuth'),
        metadata: any(named: 'metadata'),
        tags: ['urgent', 'work'],
      )).called(1);
    });

    test('credential with no parsed title passes empty title', () async {
      controller.detectTypeFromContent(_delta('serv*user*pass'));

      await controller.save();
      verify(() => mockCreateEntry(
        title: '',
        content: any(named: 'content'),
        type: EntryType.credential,
        secret: 'pass',
        requiresAuth: true,
        metadata: any(named: 'metadata'),
        tags: any(named: 'tags'),
      )).called(1);
    });

    test('throws on error — isSaving and error are set', () async {
      when(() => mockCreateEntry(
        title: any(named: 'title'),
        content: any(named: 'content'),
        type: any(named: 'type'),
        secret: any(named: 'secret'),
        requiresAuth: any(named: 'requiresAuth'),
        metadata: any(named: 'metadata'),
        tags: any(named: 'tags'),
      )).thenThrow(Exception('Save failed'));

      controller.detectTypeFromContent(_delta('hello'));
      expect(() => controller.save(), throwsA(isA<Exception>()));
      final state = container.read(createEntryControllerProvider);
      expect(state.isSaving, false);
      expect(state.error, contains('Save failed'));
    });
  });

  // =========================================================================
  // effectiveType / isManual computed getters (tested via Freezed)
  // =========================================================================

  group('computed getters (Freezed)', () {
    test('effectiveType falls back through manualType → detectedType → note', () {
      // All null → note
      var state = const CreateEntryState(title: '', content: '', tags: '');
      expect(state.effectiveType, EntryType.note);

      // Only detectedType
      state = state.copyWith(detectedType: EntryType.idea);
      expect(state.effectiveType, EntryType.idea);

      // manualType overrides detectedType
      state = state.copyWith(manualType: EntryType.task);
      expect(state.effectiveType, EntryType.task);
      expect(state.isManual, true);

      // manualType null again → falls back
      state = state.copyWith(manualType: null);
      expect(state.effectiveType, EntryType.idea);
      expect(state.isManual, false);
    });
  });
}
