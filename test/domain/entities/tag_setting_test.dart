import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';

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
}
