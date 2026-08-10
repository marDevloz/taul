import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

/// Resultado de una operación de importación.
class ImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class ImportService {
  final IEntryRepository _repository;

  ImportService({required IEntryRepository repository}) : _repository = repository;

  /// Abre un FilePicker para seleccionar un archivo .json, lo parsea,
  /// e importa las entries que no existan en la base de datos.
  ///
  /// Retorna [ImportResult] con el resumen de la operación.
  Future<ImportResult> importFromFile(BuildContext context) async {
    final pickResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (pickResult == null) {
      return const ImportResult(imported: 0, skipped: 0, errors: []);
    }

    final file = pickResult.files.single;

    // Leer el contenido del archivo
    late String jsonString;
    try {
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        return const ImportResult(
          imported: 0,
          skipped: 0,
          errors: ['No se pudo leer el archivo seleccionado'],
        );
      }
    } catch (e) {
      return ImportResult(
        imported: 0,
        skipped: 0,
        errors: ['Error al leer el archivo: $e'],
      );
    }

    return importFromJsonString(jsonString);
  }

  /// Importa las entries contenidas en un string JSON en formato de
  /// exportación (un wrapper con "version" y "entries").
  ///
  /// Las entries cuyo ID ya exista en la base de datos se saltan.
  /// Retorna un [ImportResult] con el resumen de la operación.
  Future<ImportResult> importFromJsonString(String jsonString) async {
    // Parsear el JSON
    late Map<String, dynamic> wrapper;
    try {
      wrapper = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return ImportResult(
        imported: 0,
        skipped: 0,
        errors: ['El archivo no es un JSON válido: $e'],
      );
    }

    // Validar formato del wrapper
    if (wrapper['version'] == null || wrapper['entries'] == null) {
      return const ImportResult(
        imported: 0,
        skipped: 0,
        errors: ['Formato de archivo inválido: no se encontraron "version" o "entries"'],
      );
    }

    final entriesData = wrapper['entries'] as List<dynamic>;
    int imported = 0;
    int skipped = 0;
    final errors = <String>[];

    for (final data in entriesData) {
      try {
        final entry = Entry.fromJson(data as Map<String, dynamic>);

        // Verificar si ya existe por ID
        try {
          await _repository.getById(entry.id);
          skipped++;
        } on EntryNotFoundFailure {
          await _repository.create(entry);
          imported++;
        }
      } catch (e) {
        errors.add('Error al importar entrada: $e');
      }
    }

    return ImportResult(imported: imported, skipped: skipped, errors: errors);
  }
}
