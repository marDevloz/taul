import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
  });

  tearDown(() {
    database.close();
  });

  Future<void> insertEntry(
    String id,
    String title,
    String content, {
    List<String> tags = const [],
  }) {
    return dao.insert(Entry(
      id: id,
      type: EntryType.note,
      title: title,
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  group('EntryDao.searchWithSnippets (FTS5 path)', () {
    test('should_return_snippet_with_highlight_ranges_for_content_match',
        () async {
      await insertEntry('1', 'Notas', 'Contenido sobre Flutter y más cosas');

      final results = await dao.searchWithSnippets('Flutter');

      expect(results.length, 1);
      final snippet = results.first.snippet;
      expect(snippet, isNotNull);
      expect(snippet!.text, contains('Flutter'));
      final termPos = snippet.text.toLowerCase().indexOf('flutter');
      expect(termPos, greaterThanOrEqualTo(0));
      expect(
        snippet.highlights,
        contains((start: termPos, end: termPos + 'flutter'.length)),
      );
    });

    test('should_include_search_terms_and_match_entry', () async {
      await insertEntry('1', 'Notas', 'Aprendo Flutter cada día');

      final results = await dao.searchWithSnippets('Flutter');

      expect(results.first.entry.id, '1');
      expect(results.first.terms, ['Flutter']);
    });

    test('should_support_multiple_tokens_with_distinct_highlights', () async {
      await insertEntry('1', 'Notas', 'Aprendo Flutter y también Dart');

      final results = await dao.searchWithSnippets('Flutter Dart');

      final snippet = results.first.snippet!;
      for (final term in ['Flutter', 'Dart']) {
        final termPos = snippet.text.toLowerCase().indexOf(term.toLowerCase());
        expect(termPos, greaterThanOrEqualTo(0));
        expect(
          snippet.highlights.any(
            (h) =>
                h.start == termPos &&
                h.end == termPos + term.length,
          ),
          isTrue,
        );
      }
    });

    test('should_not_return_snippet_when_match_is_only_in_title', () async {
      await insertEntry('1', 'Flutter notes', 'Contenido sin la palabra');

      final results = await dao.searchWithSnippets('Flutter');

      expect(results.length, 1);
      expect(results.first.snippet, isNull);
      expect(results.first.terms, ['Flutter']);
    });

    test('should_return_empty_for_unknown_query', () async {
      await insertEntry('1', 'Notas', 'Contenido');

      final results = await dao.searchWithSnippets('zzzznotfound');

      expect(results, isEmpty);
    });

    test('should_return_empty_for_empty_query', () async {
      await insertEntry('1', 'Notas', 'Contenido');

      expect(await dao.searchWithSnippets(''), isEmpty);
      expect(await dao.searchWithSnippets('   '), isEmpty);
    });

    test('should_return_deep_content_match_as_centered_snippet', () async {
      final filler = List.filled(30, 'relleno').join(' ');
      await insertEntry('1', 'Notas', '$filler flor $filler');

      final results = await dao.searchWithSnippets('flor');

      expect(results.length, 1);
      final snippet = results.first.snippet!;
      // El match está en el medio: el snippet no es el contenido completo
      // y viene con ellipsis de ambos lados.
      expect(snippet.text, isNot(contains('$filler flor $filler')));
      expect(snippet.text.startsWith('…'), isTrue);
      expect(snippet.text.endsWith('…'), isTrue);
      final termPos = snippet.text.toLowerCase().indexOf('flor');
      expect(termPos, greaterThanOrEqualTo(0));
      expect(
        snippet.highlights,
        contains((start: termPos, end: termPos + 4)),
      );
    });
  });

  group('EntryDao.searchWithSnippets when FTS5 unavailable (LIKE path)',
      () {
    setUp(() async {
      await database.customStatement('DROP TABLE entries_fts');
    });

    test('should_return_snippet_with_same_shape_via_like', () async {
      await insertEntry('1', 'Notas', 'Contenido sobre Flutter y más cosas');

      final results = await dao.searchWithSnippets('Flutter');

      expect(results.length, 1);
      expect(results.first.entry.id, '1');
      final snippet = results.first.snippet;
      expect(snippet, isNotNull);
      final termPos = snippet!.text.toLowerCase().indexOf('flutter');
      expect(termPos, greaterThanOrEqualTo(0));
      expect(
        snippet.highlights,
        contains((start: termPos, end: termPos + 'flutter'.length)),
      );
    });

    test('should_highlight_term_in_deep_content_via_like', () async {
      final filler = List.filled(30, 'relleno').join(' ');
      await insertEntry('1', 'Notas', '$filler arquitectura $filler');

      final results = await dao.searchWithSnippets('arquitectura');

      final snippet = results.first.snippet!;
      expect(snippet.text.startsWith('…'), isTrue);
      final termPos = snippet.text.toLowerCase().indexOf('arquitectura');
      expect(termPos, greaterThanOrEqualTo(0));
      expect(
        snippet.highlights,
        contains((start: termPos, end: termPos + 'arquitectura'.length)),
      );
    });

    test('should_apply_active_filters_via_like_with_snippets', () async {
      await insertEntry('1', 'Notas', 'Contenido sobre Flutter', tags: ['work']);
      await insertEntry('2', 'Notas', 'Contenido sobre Flutter', tags: ['personal']);

      final results = await dao.searchWithSnippets('Flutter', tag: 'work');

      expect(results.map((m) => m.entry.id), ['1']);
    });
  });
}
