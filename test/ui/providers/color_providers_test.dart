import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/shared/tag_color_mixer.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';

/// Helper to create a test Entry with given tags and no tagsColors.
Entry _entry({
  required String id,
  List<String> tags = const [],
}) {
  return Entry(
    id: id,
    type: EntryType.note,
    title: 'Test',
    content: 'Content',
    metadata: const {},
    tags: tags,
    tagsColors: const {},
    requiresAuth: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Builds a TagSetting with the given name and optional color.
TagSetting _tagSetting(String name, {String? color}) {
  return TagSetting(
    name: name,
    color: color,
    createdAt: DateTime.now(),
  );
}

/// Helper: creates a ProviderContainer with overrides for the given entry
/// and tag settings map, then resolves the entry future so that
/// [entryDisplayColorProvider] can access the entry data synchronously.
Future<Color?> _readEntryDisplay(
  String entryId,
  Entry entry,
  Map<String, TagSetting> tagMap,
) async {
  final container = ProviderContainer(
    overrides: [
      entryDetailProvider(entryId).overrideWith(
        (ref) async => entry,
      ),
      tagSettingsMapProvider.overrideWith((ref) => tagMap),
    ],
  );
  addTearDown(container.dispose);

  // Pump microtasks so the FutureProvider resolves
  await container.read(entryDetailProvider(entryId).future);

  return container.read(entryDisplayColorProvider(entryId));
}

/// Helper for tagColorForEntryProvider (doesn't depend on entryDetailProvider).
Color? _readTagColorForEntry(
  String tag,
  Map<String, TagSetting> tagMap,
) {
  final container = ProviderContainer(
    overrides: [
      tagSettingsMapProvider.overrideWith((ref) => tagMap),
      // entryDetailProvider is also watched by tagColorForEntryProvider;
      // override it to avoid creating real DB connections
      entryDetailProvider('any').overrideWith((ref) async => _entry(id: 'any')),
    ],
  );
  addTearDown(container.dispose);

  return container.read(tagColorForEntryProvider(('any', tag)));
}

void main() {
  group('entryDisplayColorProvider', () {
    test('should return null when entry has no tags', () async {
      final result = await _readEntryDisplay(
        'e1',
        _entry(id: 'e1', tags: []),
        {},
      );
      expect(result, isNull);
    });

    test(
      'should return defaultGrey when tags have no color assignments',
      () async {
        final result = await _readEntryDisplay(
          'e1',
          _entry(id: 'e1', tags: ['urgent']),
          {'urgent': _tagSetting('urgent')}, // no color
        );
        expect(result, TagPalette.defaultGrey);
      },
    );

    test('should return single color when one tag has a color', () async {
      final result = await _readEntryDisplay(
        'e1',
        _entry(id: 'e1', tags: ['urgent']),
        {'urgent': _tagSetting('urgent', color: '#E06C75')},
      );
      expect(result, const Color(0xFFE06C75));
    });

    test('should return mixed color for N colored tags', () async {
      final tags = ['urgent', 'work', 'personal'];
      final colors = {
        'urgent': '#E06C75',
        'work': '#61AFEF',
        'personal': '#98C379',
      };
      final result = await _readEntryDisplay(
        'e1',
        _entry(id: 'e1', tags: tags),
        {
          for (final name in tags)
            name: _tagSetting(name, color: colors[name]),
        },
      );

      final expected = TagColorMixer.mix(
        colors.values
            .map(
              (h) =>
                  Color(int.parse(h.substring(1), radix: 16) + 0xFF000000),
            )
            .toList(),
      );
      expect(result, expected);
    });

    test(
      'should use case-insensitive lookup from tagSettingsMap',
      () async {
        // entry has mixed-case tag, but tagSettingsMap has lowercase key
        final result = await _readEntryDisplay(
          'e1',
          _entry(id: 'e1', tags: ['Urgent']),
          {'urgent': _tagSetting('urgent', color: '#E06C75')},
        );
        expect(result, const Color(0xFFE06C75));
      },
    );
  });

  group('tagColorForEntryProvider', () {
    test('should return resolved color for matching tag', () {
      final result = _readTagColorForEntry('urgent', {
        'urgent': _tagSetting('urgent', color: '#E06C75'),
      });
      expect(result, const Color(0xFFE06C75));
    });

    test('should return null for unknown tag', () {
      final result = _readTagColorForEntry('nonexistent', {});
      expect(result, isNull);
    });
  });
}
