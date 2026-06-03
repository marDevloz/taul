// Run: dart run tool/check_db.dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final home = Platform.environment['USERPROFILE'] ?? '';
  final dbPath = '$home\\OneDrive\\Documentos\\taul.db';
  
  if (!File(dbPath).existsSync()) {
    print('ERROR: Database not found at $dbPath');
    return;
  }
  
  final db = sqlite3.open(dbPath);
  
  print('=== SCHEMA VERSION ===');
  print('PRAGMA user_version = ${db.userVersion}');
  
  print('\n=== TAG SETTINGS ===');
  final tags = db.select('SELECT name, color, is_system, is_secure FROM tag_settings ORDER BY name');
  for (final row in tags) {
    print('  ${row['name']}  color=${row['color']}  is_system=${row['is_system']}  is_secure=${row['is_secure']}');
  }
  
  print('\n=== ENTRIES ===');
  final entries = db.select('SELECT id, type, title, tags, created_at FROM entries ORDER BY created_at');
  print('  Count: ${entries.length}');
  for (final row in entries) {
    print('  ${row['id']}  type=${row['type']}  title=${row['title']}  tags=${row['tags']}');
  }
  
  db.dispose();
}
