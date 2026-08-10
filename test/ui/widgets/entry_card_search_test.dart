import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/search_match.dart';
import 'package:taul/ui/widgets/entry_card.dart';

/// Recorre los [TextSpan] anidados buscando un span con el [term] resaltado
/// en negrita.
bool _containsHighlight(InlineSpan span, String term) {
  if (span is! TextSpan) return false;
  final text = span.text ?? '';
  if (text.contains(term) &&
      span.style?.fontWeight == FontWeight.bold &&
      span.style?.color != null) {
    return true;
  }
  final children = span.children;
  if (children != null) {
    for (final child in children) {
      if (_containsHighlight(child, term)) return true;
    }
  }
  return false;
}

bool _cardHasHighlight(WidgetTester tester, String term) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  return richTexts.any((rt) => _containsHighlight(rt.text, term));
}

void main() {
  final entry = Entry(
    id: '1',
    type: EntryType.note,
    title: 'Mi nota de Flutter',
    content: 'Aprendo Flutter todos los días',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget wrap(Widget card) {
    return MaterialApp(home: Scaffold(body: card));
  }

  group('EntryCard search highlighting', () {
    testWidgets('should_render_highlighted_term_in_snippet_when_provided',
        (tester) async {
      const snippet = SearchSnippet(
        text: '…Aprendo Flutter todos los días…',
        highlights: [(start: 9, end: 16)],
      );

      await tester.pumpWidget(
        wrap(
          EntryCard(
            entry: entry,
            searchSnippet: snippet,
            searchTerms: const ['Flutter'],
          ),
        ),
      );

      expect(_cardHasHighlight(tester, 'Flutter'), isTrue);
    });

    testWidgets('should_render_highlighted_term_in_title_when_title_matches',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          EntryCard(
            entry: entry,
            searchTerms: const ['Flutter'],
          ),
        ),
      );

      expect(_cardHasHighlight(tester, 'Flutter'), isTrue);
    });

    testWidgets('should_highlight_both_title_and_snippet_when_both_match',
        (tester) async {
      const snippet = SearchSnippet(
        text: 'Aprendo Flutter todos los días',
        highlights: [(start: 8, end: 15)],
      );

      await tester.pumpWidget(
        wrap(
          EntryCard(
            entry: entry,
            searchSnippet: snippet,
            searchTerms: const ['Flutter'],
          ),
        ),
      );

      // Al menos dos RichText resaltan el término: título y snippet.
      final count = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((rt) => _containsHighlight(rt.text, 'Flutter'))
          .length;
      expect(count, greaterThanOrEqualTo(2));
    });

    testWidgets('should_not_render_highlight_when_no_snippet_or_terms',
        (tester) async {
      await tester.pumpWidget(wrap(EntryCard(entry: entry)));

      expect(_cardHasHighlight(tester, 'Flutter'), isFalse);
    });

    testWidgets('should_fall_back_to_plain_preview_when_snippet_null',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          EntryCard(
            entry: entry,
            searchTerms: const ['Flutter'],
          ),
        ),
      );

      // La preview de contenido sigue siendo el texto plano normal.
      expect(find.textContaining('Aprendo Flutter todos los días'), findsOneWidget);
    });
  });
}
