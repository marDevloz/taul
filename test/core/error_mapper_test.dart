import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/core/errors/error_mapper.dart';

class _FakeDatabaseException extends DatabaseException {
  _FakeDatabaseException(super.message);

  @override
  int? getResultCode() => 1;

  @override
  Object? get result => <String, Object?>{};
}

void main() {
  const mapper = ErrorMapper();

  group('ErrorMapper.toUserMessage', () {
    test('should_return_search_unavailable_message_when_fts5_table_missing', () {
      final error = SqliteException(1, 'no such table: entries_fts');

      expect(mapper.toUserMessage(error), ErrorMapper.searchUnavailableMessage);
    });

    test('should_return_search_unavailable_message_when_fts5_module_missing', () {
      final error = SqliteException(1, 'no such module: fts5');

      expect(mapper.toUserMessage(error), ErrorMapper.searchUnavailableMessage);
    });

    test('should_return_search_unavailable_message_when_sqflite_missing_fts', () {
      final error = _FakeDatabaseException('no such table: entries_fts');

      expect(mapper.toUserMessage(error), ErrorMapper.searchUnavailableMessage);
    });

    test('should_return_database_message_when_sqlite_exception', () {
      final error = SqliteException(1, 'database is locked');

      expect(mapper.toUserMessage(error), ErrorMapper.databaseMessage);
    });

    test('should_return_database_message_when_sqflite_exception', () {
      final error = _FakeDatabaseException('database is locked');

      expect(mapper.toUserMessage(error), ErrorMapper.databaseMessage);
    });

    test('should_return_decrypt_message_when_authentication_error', () {
      expect(
        mapper.toUserMessage(SecretBoxAuthenticationError()),
        ErrorMapper.decryptMessage,
      );
    });

    test('should_return_decrypt_message_when_padding_error', () {
      expect(
        mapper.toUserMessage(SecretBoxPaddingError()),
        ErrorMapper.decryptMessage,
      );
    });

    test('should_return_file_message_when_file_system_exception', () {
      const error = FileSystemException('Cannot open file', '/tmp/taul.bin');

      expect(mapper.toUserMessage(error), ErrorMapper.fileMessage);
    });

    test('should_return_unexpected_message_when_unknown_error', () {
      expect(
        mapper.toUserMessage(Exception('boom')),
        ErrorMapper.unexpectedMessage,
      );
    });

    test('should_return_action_message_when_unknown_error_in_action_context', () {
      expect(
        mapper.toUserMessage(
          Exception('boom'),
          actionMessage: ErrorMapper.saveErrorMessage,
        ),
        ErrorMapper.saveErrorMessage,
      );
    });
  });
}
