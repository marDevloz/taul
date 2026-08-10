import 'dart:io';

import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError, SecretBoxPaddingError;
import 'package:sqflite/sqflite.dart' show DatabaseException;
import 'package:sqlite3/sqlite3.dart';

/// Maps technical exceptions into user-friendly Spanish messages.
///
/// The UI must never surface raw exception text to the user: callers should
/// display the message returned by [ErrorMapper.toUserMessage] and keep the
/// original exception in logs for diagnostics.
class ErrorMapper {
  const ErrorMapper();

  /// Message for unexpected errors with no specific mapping.
  static const unexpectedMessage =
      'Ocurrió un error inesperado. Inténtalo de nuevo.';

  /// Message when the database cannot be accessed.
  static const databaseMessage =
      'Error al acceder a los datos. Inténtalo de nuevo.';

  /// Message when full-text search (FTS5) is not available on the device.
  static const searchUnavailableMessage =
      'La búsqueda avanzada no está disponible en este dispositivo.';

  /// Message when encrypted content cannot be decrypted.
  static const decryptMessage =
      'No se pudo descifrar el contenido. Verificá que la contraseña '
      'maestra sea la correcta.';

  /// Message when a file cannot be read or written.
  static const fileMessage =
      'No se pudo leer o escribir el archivo. Verificá la ubicación '
      'e inténtalo de nuevo.';

  /// Action-specific fallbacks for snackbars that know what failed.
  static const saveErrorMessage = 'Error al guardar la entrada';
  static const exportErrorMessage = 'No se pudieron exportar los datos';
  static const importErrorMessage = 'No se pudieron importar los datos';
  static const regenerateCodesErrorMessage =
      'No se pudieron regenerar los códigos de respaldo';

  /// Returns a user-friendly Spanish message for [error].
  ///
  /// [actionMessage] is used as the fallback when the error is unknown and
  /// the caller knows which action failed (e.g. "Error al guardar la
  /// entrada"). Defaults to [unexpectedMessage].
  String toUserMessage(
    Object error, {
    String actionMessage = unexpectedMessage,
  }) {
    if (_isFtsError(error)) return searchUnavailableMessage;
    if (error is SqliteException || error is DatabaseException) {
      return databaseMessage;
    }
    if (error is SecretBoxAuthenticationError ||
        error is SecretBoxPaddingError) {
      return decryptMessage;
    }
    if (error is FileSystemException) return fileMessage;
    return actionMessage;
  }

  bool _isFtsError(Object error) {
    final text = error is SqliteException ? error.message : error.toString();
    final lower = text.toLowerCase();
    return lower.contains('entries_fts') || lower.contains('fts5');
  }
}
