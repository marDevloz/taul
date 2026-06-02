import 'package:flutter_test/flutter_test.dart';
import 'package:taul/shared/tag_palette.dart';

void main() {
  group('TagPalette.systemTagDefaults', () {
    test('should_have_four_entries', () {
      expect(TagPalette.systemTagDefaults, hasLength(4));
    });

    test('should_contain_expected_keys', () {
      expect(
        TagPalette.systemTagDefaults.keys,
        containsAll(['pendiente', 'completada', 'favorito', 'archivado']),
      );
    });

    test('should_have_amber_for_pendiente', () {
      final pendiente = TagPalette.systemTagDefaults['pendiente']!;
      expect(pendiente.hex, '#FFC107');
    });

    test('should_have_green_for_completada', () {
      final completada = TagPalette.systemTagDefaults['completada']!;
      expect(completada.hex, '#4CAF50');
    });

    test('should_have_red_for_favorito', () {
      final favorito = TagPalette.systemTagDefaults['favorito']!;
      expect(favorito.hex, '#E53935');
    });

    test('should_have_grey_for_archivado', () {
      final archivado = TagPalette.systemTagDefaults['archivado']!;
      expect(archivado.hex, '#9E9E9E');
    });
  });
}
