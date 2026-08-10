import 'package:shared_preferences/shared_preferences.dart';

/// Persists the timestamp of the last successful encrypted backup.
class BackupTimestampStore {
  static const String lastBackupAtKey = 'last_backup_at';

  /// Returns the date of the last successful encrypted backup, or null
  /// if no backup has been recorded yet.
  Future<DateTime?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastBackupAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Records the timestamp of a successful encrypted backup, stored as UTC.
  Future<void> recordBackup({required DateTime timestamp}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastBackupAtKey, timestamp.toUtc().toIso8601String());
  }
}