import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Helper para manejar contenido de texto enriquecido con flutter_quill.
///
/// El [Entry.content] guarda Delta JSON como string para las entradas con
/// formato. Las entradas legacy (texto plano) se detectan automáticamente
/// y se convierten.
class RichTextHelper {
  RichTextHelper._();

  /// Indica si [content] es Delta JSON (rich text) o texto plano legacy.
  static bool isRichText(String content) {
    if (content.isEmpty) return false;
    try {
      final decoded = jsonDecode(content);
      return decoded is List && decoded.isNotEmpty && decoded[0] is Map;
    } catch (_) {
      return false;
    }
  }

  /// Convierte texto plano legacy a un [Document] de Quill.
  static Document plainTextToDocument(String text) {
    return Document.fromJson([<String, dynamic>{'insert': '$text\n'}]);
  }

  /// Convierte un [Document] de Quill a texto plano (sin formato).
  static String documentToPlainText(Document doc) {
    return doc.toPlainText();
  }

  /// Convierte un [Document] de Quill a Delta JSON string.
  static String documentToJson(Document doc) {
    return jsonEncode(doc.toDelta().toJson());
  }

  /// Obtiene un [Document] desde el contenido legacy o Delta JSON.
  static Document getDocument(String content) {
    if (content.isEmpty) return Document();
    if (isRichText(content)) {
      try {
        return Document.fromJson(jsonDecode(content) as List);
      } catch (_) {
        return plainTextToDocument(content);
      }
    }
    return plainTextToDocument(content);
  }

  /// Extrae los `-#tag` de un texto plano y devuelve el texto limpio + los tags.
  ///
  /// El formato exacto es `-#tag` — el `-` antes de `#` es el marker.
  /// Los tags pueden contener guiones: `-#gol-caracol`.
  static ({String clean, List<String> tags}) extractTags(String raw) {
    final re = RegExp(r'-#([\w-]+)');
    final matches = re.allMatches(raw);
    final tags = matches.map((m) => m.group(1)!).toList();
    final clean = raw.replaceAll(re, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return (clean: clean, tags: tags);
  }

  /// Removes all `-#tagName` markers from rich text (Delta JSON) content.
  ///
  /// Iterates each Delta operation and strips the exact `-#tagName` text
  /// from insert strings. Preserves all formatting attributes on remaining
  /// text. If [tagNames] is empty, returns the content unchanged.
  static String stripTagsFromContent(String jsonContent, List<String> tagNames) {
    if (tagNames.isEmpty || jsonContent.isEmpty) return jsonContent;

    final doc = getDocument(jsonContent);
    final ops = doc.toDelta().toJson();

    final cleanedOps = <Map<String, dynamic>>[];
    for (final op in ops) {
      if (op['insert'] is String) {
        var text = op['insert'] as String;
        final original = text;
        for (final tag in tagNames) {
          text = text.replaceAll('-#$tag', '');
        }
        if (text.isEmpty) continue; // remove empty operations
        cleanedOps.add({...op, 'insert': text != original ? text : original});
      } else {
        cleanedOps.add(op);
      }
    }

    return jsonEncode(cleanedOps);
  }

  /// Si [content] tiene un separador `:`, devuelve Delta JSON con el término
  /// en **negrita** (mayúscula inicial), `: `, y la definición en *cursiva*
  /// (mayúscula inicial). Si no hay `:`, devuelve el contenido sin cambios.
  ///
  /// Acepta tanto texto plano como Delta JSON de entrada.
  static String formatForGlossary(String content) {
    final plainText = documentToPlainText(getDocument(content));

    final colonIdx = plainText.indexOf(':');
    if (colonIdx < 0) return content;

    final term = plainText.substring(0, colonIdx).trim();
    final definition = plainText.substring(colonIdx + 1).trim();

    final capitalizedTerm = term.isNotEmpty
        ? '${term[0].toUpperCase()}${term.substring(1)}'
        : '';
    final capitalizedDef = definition.isNotEmpty
        ? '${definition[0].toUpperCase()}${definition.substring(1)}'
        : '';

    return jsonEncode([
      {'insert': capitalizedTerm, 'attributes': {'bold': true}},
      {'insert': ': '},
      {'insert': capitalizedDef, 'attributes': {'italic': true}},
      {'insert': '\n'},
    ]);
  }
}
