import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/infrastructure/export/encrypted_export_service.dart';

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

/// Resultado de elegir un archivo de importación y clasificarlo.
///
/// - [json]: contenido del archivo, o null si el usuario canceló la selección
///   o el archivo no se pudo leer.
/// - [encrypted]: true cuando el wrapper del archivo declara
///   `"encrypted": true` (es decir, es un backup cifrado).
/// - [error]: mensaje amigable cuando el archivo no se pudo leer o no es un
///   JSON válido; null en caso contrario.
class PickedImportFile {
  final String? json;
  final bool encrypted;
  final String? error;

  const PickedImportFile({
    required this.json,
    required this.encrypted,
    this.error,
  });
}

class ImportService {
  /// Mensaje cuando la contraseña de un backup cifrado es incorrecta o el
  /// archivo está dañado.
  static const wrongPassphraseErrorMessage =
      'Contraseña incorrecta o archivo de backup dañado';

  static const _notEncryptedBackupErrorMessage =
      'El archivo seleccionado no es un backup cifrado';
  static const _invalidJsonErrorMessage =
      'El archivo seleccionado no es un JSON válido';
  static const _unreadableErrorMessage =
      'No se pudo leer el archivo seleccionado';

  final IEntryRepository _repository;

  ImportService({required IEntryRepository repository}) : _repository = repository;

  /// Abre un FilePicker para seleccionar un archivo .json, lo lee y lo
  /// clasifica (¿es un backup cifrado?).
  ///
  /// Retorna [PickedImportFile] con el contenido y la clasificación. El
  /// contenido es null si el usuario canceló la selección.
  Future<PickedImportFile> pickImportFile(BuildContext context) async {
    final pickResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (pickResult == null) {
      return const PickedImportFile(json: null, encrypted: false);
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
        return const PickedImportFile(
          json: null,
          encrypted: false,
          error: _unreadableErrorMessage,
        );
      }
    } catch (_) {
      return const PickedImportFile(
        json: null,
        encrypted: false,
        error: _unreadableErrorMessage,
      );
    }

    // Clasificar el wrapper del archivo.
    var encrypted = false;
    try {
      final wrapper = jsonDecode(jsonString);
      if (wrapper is Map<String, dynamic>) {
        encrypted = wrapper['encrypted'] == true;
      }
    } catch (_) {
      return const PickedImportFile(
        json: null,
        encrypted: false,
        error: _invalidJsonErrorMessage,
      );
    }

    return PickedImportFile(json: jsonString, encrypted: encrypted);
  }

  /// Abre un FilePicker para seleccionar un archivo .json plano (no cifrado),
  /// lo parsea, e importa las entries que no existan en la base de datos.
  ///
  /// Retorna [ImportResult] con el resumen de la operación. Los archivos
  /// cifrados no se pueden importar por esta vía: la importación cifrada
  /// requiere [importEncryptedJson].
  Future<ImportResult> importFromFile(BuildContext context) async {
    final picked = await pickImportFile(context);

    if (picked.error != null) {
      return ImportResult(
        imported: 0,
        skipped: 0,
        errors: [picked.error!],
      );
    }
    if (picked.json == null) {
      return const ImportResult(imported: 0, skipped: 0, errors: []);
    }
    if (picked.encrypted) {
      return const ImportResult(
        imported: 0,
        skipped: 0,
        errors: [_notEncryptedBackupErrorMessage],
      );
    }
    return importFromJsonString(picked.json!);
  }

  /// Descifra un backup cifrado ([json]) con [passphrase] e importa las
  /// entries resultantes.
  ///
  /// Cuando la contraseña es incorrecta o el archivo está dañado retorna un
  /// [ImportResult] con un único error amigable ([wrongPassphraseErrorMessage])
  /// y sin entradas importadas.
  Future<ImportResult> importEncryptedJson(
    String json, {
    required String passphrase,
    required EncryptedExportService exportService,
  }) async {
    final decrypted = await exportService.decryptExport(
      encryptedJson: json,
      passphrase: passphrase,
    );

    if (decrypted == null) {
      return const ImportResult(
        imported: 0,
        skipped: 0,
        errors: [wrongPassphraseErrorMessage],
      );
    }

    return importFromJsonString(decrypted);
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
