import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:taul/domain/entities/entry.dart';

class ExportService {
  /// Serializa una lista de [Entry] a JSON con formato legible.
  /// Incluye metadata del archivo de exportación.
  String exportToJson(List<Entry> entries) {
    final wrapper = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entryCount': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(wrapper);
  }

  /// Abre un diálogo para que el usuario elija dónde guardar el archivo
  /// y escribe [json] en esa ubicación.
  ///
  /// Retorna la ruta del archivo guardado, o `null` si el usuario cancela.
  Future<String?> saveToFile(String json, BuildContext context) async {
    final now = DateTime.now();
    final defaultName =
        'taul-export-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';

    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Guardar exportación',
      fileName: defaultName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );

    if (outputPath == null) return null;

    try {
      await File(outputPath).writeAsString(json);
      return outputPath;
    } catch (e) {
      rethrow;
    }
  }
}
