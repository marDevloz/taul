import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/infrastructure/database/app_database.dart' as db;

void main() {
  group('TagSetting', () {
    test('should_default_isSystem_to_false', () {
      final tag = TagSetting(
        name: 'test',
        createdAt: DateTime.now(),
      );
      expect(tag.isSystem, false);
    });

    test('should_set_isSystem_to_true', () {
      final tag = TagSetting(
        name: 'system',
        createdAt: DateTime.now(),
        isSystem: true,
      );
      expect(tag.isSystem, true);
    });

    test('should_preserve_existing_fields_with_isSystem', () {
      final now = DateTime.now();
      final tag = TagSetting(
        name: 'favorito',
        color: '#FF0000',
        isSecure: true,
        isSystem: true,
        createdAt: now,
      );
      expect(tag.name, 'favorito');
      expect(tag.color, '#FF0000');
      expect(tag.isSecure, true);
      expect(tag.isSystem, true);
      expect(tag.createdAt, now);
    });
  });

  group('TagSetting JSON serde', () {
    test('should_round_trip_isSystem_true_via_json', () {
      final createdAt = DateTime(2026, 5, 31, 12, 0, 0);
      final tag = db.TagSetting(
        name: 'pendiente',
        color: '#FFC107',
        isSecure: false,
        isSystem: true,
        createdAt: createdAt,
      );

      final json = tag.toJson();
      final restored = db.TagSetting.fromJson(json);

      expect(restored.name, 'pendiente');
      expect(restored.color, '#FFC107');
      expect(restored.isSecure, false);
      expect(restored.isSystem, true);
      expect(restored.createdAt, createdAt);
    });

    test('should_round_trip_isSystem_false_via_json', () {
      final createdAt = DateTime(2026, 5, 31, 12, 0, 0);
      final tag = db.TagSetting(
        name: 'user-tag',
        color: '#61AFEF',
        isSecure: true,
        isSystem: false,
        createdAt: createdAt,
      );

      final json = tag.toJson();
      final restored = db.TagSetting.fromJson(json);

      expect(restored.name, 'user-tag');
      expect(restored.color, '#61AFEF');
      expect(restored.isSecure, true);
      expect(restored.isSystem, false);
      expect(restored.createdAt, createdAt);
    });

    test('should_round_trip_isSystem_with_null_color', () {
      final createdAt = DateTime(2026, 5, 31, 12, 0, 0);
      final tag = db.TagSetting(
        name: 'no-color',
        isSecure: false,
        isSystem: true,
        createdAt: createdAt,
      );

      final json = tag.toJson();
      final restored = db.TagSetting.fromJson(json);

      expect(restored.name, 'no-color');
      expect(restored.color, isNull);
      expect(restored.isSecure, false);
      expect(restored.isSystem, true);
      expect(restored.createdAt, createdAt);
    });
  });
}
