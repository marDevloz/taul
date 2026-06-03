// Run: dart run tool/fix_db.dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final home = Platform.environment['USERPROFILE'] ?? '';
  final dbPath = '$home\\OneDrive\\Documentos\\taul.db';
  
  if (!File(dbPath).existsSync()) {
    print('ERROR: Database not found at $dbPath');
    return;
  }

  // Backup
  final backupPath = '$dbPath.backup';
  File(dbPath).copySync(backupPath);
  print('Backup saved to $backupPath');
  
  final db = sqlite3.open(dbPath);
  
  print('=== BEFORE FIX ===');
  var tags = db.select('SELECT name, color, is_system, is_secure FROM tag_settings ORDER BY name');
  for (final row in tags) {
    print('  ${row['name']}  color=${row['color']}  is_system=${row['is_system']}');
  }
  print('user_version = ${db.userVersion}');

  // Manually run the v11 migration SQL
  final systemTags = {
    'pendiente': '#FFC107',
    'completada': '#4CAF50', 
    'favorito': '#E53935',
    'archivado': '#9E9E9E',
  };
  
  for (final entry in systemTags.entries) {
    db.execute('INSERT OR IGNORE INTO tag_settings (name, color, is_secure, is_system) VALUES (?, ?, 0, 1)',
        [entry.key, entry.value]);
    db.execute('UPDATE tag_settings SET is_system = 1 WHERE name = ?', [entry.key]);
  }
  
  print('\n=== AFTER SQL FIX ===');
  tags = db.select('SELECT name, color, is_system, is_secure FROM tag_settings ORDER BY name');
  for (final row in tags) {
    print('  ${row['name']}  color=${row['color']}  is_system=${row['is_system']}');
  }

  // Also re-insert 'favorito' with proper name if it was renamed
  // Check if 'favorito' was created by migration
  final favoritoExists = db.select("SELECT COUNT(*) as c FROM tag_settings WHERE name = 'favorito'").first['c'];
  if (favoritoExists == 0) {
    print('\nNOTE: favorito tag not found (was probably renamed). Migration INSERT OR IGNORE should have created it.');
  }
  
  db.dispose();
  print('\nDone. To restore backup, rename $backupPath -> $dbPath');
}
