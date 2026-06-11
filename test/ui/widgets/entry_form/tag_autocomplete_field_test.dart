import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/widgets/entry_form/tag_autocomplete_field.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';

/// Fake repository that returns predefined tags.
class _FakeTagSettingsRepository implements ITagSettingsRepository {
  final List<TagSetting> tags;

  _FakeTagSettingsRepository(this.tags);

  @override
  Future<List<TagSetting>> getAll() async => tags;

  @override
  Future<List<TagSetting>> getSystemTags() async => [];

  @override
  Future<List<TagSetting>> getUserTags() async => tags;

  @override
  Future<void> save(String name, {String? color, bool isSecure = false, bool isSystem = false}) async {}

  @override
  Future<void> delete(String name) async {}

  @override
  Future<void> updateColor(String name, String? color) async {}

  @override
  Future<void> updateSecure(String name, bool isSecure) async {}

  @override
  Future<void> seedSystemTags() async {}

  @override
  Future<TagSetting?> getByName(String name) async =>
      tags.where((t) => t.name == name).firstOrNull;
}

final _allTags = [
  TagSetting(name: 'trabajo', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
  TagSetting(name: 'personal', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
];

Widget _buildApp({
  required String? editorHashTagPartial,
  required String tagsFieldPartial,
  required String tagsText,
  required ValueChanged<String> onAcceptSuggestion,
  List<TagSetting>? allTags,
}) {
  final tagSettingsRepo = _FakeTagSettingsRepository(allTags ?? _allTags);

  final container = ProviderContainer(
    overrides: [
      tagSettingsRepositoryProvider.overrideWith((ref) => tagSettingsRepo),
      tagSettingsListProvider.overrideWith((ref) async => tagSettingsRepo.getAll()),
    ],
  );
  addTearDown(container.dispose);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: TagAutocompleteField(
          editorHashTagPartial: editorHashTagPartial,
          tagsFieldPartial: tagsFieldPartial,
          tagsText: tagsText,
          onAcceptSuggestion: onAcceptSuggestion,
        ),
      ),
    ),
  );
}

void main() {
  group('TagAutocompleteField', () {
    final allTags = _allTags;

    testWidgets('should show suggestion chip when editorHashTagPartial matches',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        editorHashTagPartial: 'tra',
        tagsFieldPartial: '',
        tagsText: '',
        onAcceptSuggestion: (_) {},
        allTags: allTags,
      ));
      await tester.pump();

      expect(find.text('trabajo'), findsOneWidget);
    });

    testWidgets('should show suggestion chip when tagsFieldPartial matches',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        editorHashTagPartial: null,
        tagsFieldPartial: 'pers',
        tagsText: '',
        onAcceptSuggestion: (_) {},
        allTags: allTags,
      ));
      await tester.pump();

      expect(find.text('personal'), findsOneWidget);
    });

    testWidgets('should prefer editor suggestion over tags field',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        editorHashTagPartial: 'tra',
        tagsFieldPartial: 'pers',
        tagsText: '',
        onAcceptSuggestion: (_) {},
        allTags: allTags,
      ));
      await tester.pump();

      // Editor suggestion (trabajo) should take priority
      expect(find.text('trabajo'), findsOneWidget);
      expect(find.text('personal'), findsNothing);
    });

    testWidgets('should hide when no partial matches', (tester) async {
      await tester.pumpWidget(_buildApp(
        editorHashTagPartial: null,
        tagsFieldPartial: '',
        tagsText: '',
        onAcceptSuggestion: (_) {},
        allTags: allTags,
      ));
      await tester.pump();

      // No suggestion chip should be rendered — no Add icon visible
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('should invoke onAcceptSuggestion when chip is tapped',
        (tester) async {
      String? acceptedTag;
      await tester.pumpWidget(_buildApp(
        editorHashTagPartial: 'tra',
        tagsFieldPartial: '',
        tagsText: '',
        onAcceptSuggestion: (tag) => acceptedTag = tag,
        allTags: allTags,
      ));
      await tester.pump();

      await tester.tap(find.text('trabajo'));
      await tester.pump();

      expect(acceptedTag, 'trabajo');
    });
  });
}
