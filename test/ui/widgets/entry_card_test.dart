import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/widgets/entry_card.dart';

void main() {
  final testEntry = Entry(
    id: 'test-1',
    type: EntryType.note,
    title: 'Test Note',
    content: 'Test content',
    tags: ['tag1'],
    tagsColors: {},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    version: 1,
  );

  group('EntryCard task icon', () {
    testWidgets('should show checklist icon for task entries', (tester) async {
      final taskEntry = Entry(
        id: 'task-1',
        type: EntryType.task,
        title: 'My Task',
        content: 'Task content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(entry: taskEntry),
          ),
        ),
      );

      // Task entries should show a checklist icon
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('should show book icon for glossary entries', (tester) async {
      final glossaryEntry = Entry(
        id: 'glos-1',
        type: EntryType.glossary,
        title: 'Term',
        content: 'Definition',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(entry: glossaryEntry),
          ),
        ),
      );

      expect(find.byIcon(Icons.book), findsOneWidget);
    });
  });

  group('EntryCard favorito/archivado toggles', () {
    testWidgets('should show favorito toggle when callback provided', (tester) async {
      bool favoritoToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isFavorito: false,
              onToggleFavorito: () => favoritoToggled = true,
            ),
          ),
        ),
      );

      // Should show star_border icon (not favorited)
      expect(find.byIcon(Icons.star_border), findsOneWidget);

      // Tap the favorito toggle
      await tester.tap(find.byIcon(Icons.star_border));
      expect(favoritoToggled, isTrue);
    });

    testWidgets('should show filled star when favorito is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isFavorito: true,
              onToggleFavorito: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('should show archivado toggle when callback provided', (tester) async {
      bool archivadoToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isArchivado: false,
              onToggleArchivado: () => archivadoToggled = true,
            ),
          ),
        ),
      );

      // Should show archive_outlined icon (not archived)
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);

      // Tap the archivado toggle
      await tester.tap(find.byIcon(Icons.archive_outlined));
      expect(archivadoToggled, isTrue);
    });

    testWidgets('should show filled archive when archivado is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isArchivado: true,
              onToggleArchivado: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.archive), findsOneWidget);
    });

    testWidgets('should not show toggles when callbacks are null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(entry: testEntry),
          ),
        ),
      );

      // No star or archive icons should be present
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.archive_outlined), findsNothing);
      expect(find.byIcon(Icons.archive), findsNothing);
    });
  });

  group('EntryCard completedAt', () {
    testWidgets('should show completedAt timestamp when present', (tester) async {
      final completedEntry = Entry(
        id: 'completed-1',
        type: EntryType.task,
        title: 'Done Task',
        content: 'Completed',
        completedAt: DateTime(2024, 6, 15, 10, 30),
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 15),
        tags: ['completada'],
        version: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(entry: completedEntry),
          ),
        ),
      );

      // Should show "Completada:" label
      expect(find.textContaining('Completada:'), findsOneWidget);
    });

    testWidgets('should not show completedAt when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(entry: testEntry),
          ),
        ),
      );

      // Should NOT show "Completada:" label
      expect(find.textContaining('Completada:'), findsNothing);
    });
  });
}
