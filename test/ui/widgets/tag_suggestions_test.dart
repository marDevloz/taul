import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

void main() {
  group('filterTagSuggestions', () {
    final allTags = [
      TagSetting(name: 'trabajo', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'personal', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'urgente', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'urgentísimo', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'proyecto-alpha', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'proyecto-beta', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
    ];

    test('should return all tags when query is empty', () {
      final result = filterTagSuggestions(
        query: '',
        allTags: allTags,
        selectedTags: [],
      );
      expect(result, hasLength(allTags.length));
    });

    test('should filter by prefix match (case-insensitive)', () {
      final result = filterTagSuggestions(
        query: 'proy',
        allTags: allTags,
        selectedTags: [],
      );
      expect(result, hasLength(2));
      expect(result.map((t) => t.name), containsAll(['proyecto-alpha', 'proyecto-beta']));
    });

    test('should filter by substring match', () {
      final result = filterTagSuggestions(
        query: 'urg',
        allTags: allTags,
        selectedTags: [],
      );
      expect(result, hasLength(2));
      expect(result.map((t) => t.name), containsAll(['urgente', 'urgentísimo']));
    });

    test('should exclude already selected tags', () {
      final result = filterTagSuggestions(
        query: 'proy',
        allTags: allTags,
        selectedTags: ['proyecto-alpha'],
      );
      expect(result, hasLength(1));
      expect(result.first.name, 'proyecto-beta');
    });

    test('should handle accent-insensitive matching', () {
      final result = filterTagSuggestions(
        query: 'urgentí',
        allTags: allTags,
        selectedTags: [],
      );
      expect(result, hasLength(1));
      expect(result.first.name, 'urgentísimo');
    });

    test('should return empty list when no matches', () {
      final result = filterTagSuggestions(
        query: 'xyz',
        allTags: allTags,
        selectedTags: [],
      );
      expect(result, isEmpty);
    });

    test('should limit results to maxSuggestions', () {
      final result = filterTagSuggestions(
        query: 'proy',
        allTags: allTags,
        selectedTags: [],
        maxSuggestions: 1,
      );
      expect(result, hasLength(1));
    });
  });

  group('parseCommaSeparatedTags', () {
    test('should split comma-separated tags and trim', () {
      final result = parseCommaSeparatedTags('trabajo, personal, urgente');
      expect(result, ['trabajo', 'personal', 'urgente']);
    });

    test('should ignore empty segments', () {
      final result = parseCommaSeparatedTags('trabajo,, personal, ');
      expect(result, ['trabajo', 'personal']);
    });

    test('should handle single tag', () {
      final result = parseCommaSeparatedTags('trabajo');
      expect(result, ['trabajo']);
    });

    test('should return empty list for empty string', () {
      final result = parseCommaSeparatedTags('');
      expect(result, isEmpty);
    });
  });
}
