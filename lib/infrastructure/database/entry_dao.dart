import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';

import 'app_database.dart' as db;

class EntryDao {
  final db.AppDatabase _database;

  const EntryDao(this._database);

  Future<Entry> insert(Entry entry) async {
    await _database.into(_database.entries).insert(_toCompanion(entry));
    await _syncFts(entry);
    return entry;
  }

  Future<Entry> update(Entry entry) async {
    final companion = _toCompanion(entry);
    await (_database.update(_database.entries)
      ..where((t) => t.id.equals(entry.id)))
        .write(companion);
    await _syncFts(entry);
    return entry;
  }

  Future<void> updateTagsColors(String id, Map<String, String> tagsColors) async {
    final tagsColorValue =
        tagsColors.isEmpty ? const Value(null) : Value(jsonEncode(tagsColors));
    await (_database.update(_database.entries)
      ..where((t) => t.id.equals(id)))
        .write(db.EntriesCompanion(tagsColor: tagsColorValue));
  }

  Future<void> delete(String id) async {
    await (_database.delete(_database.entries)
      ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<Entry?> get(String id) async {
    final row = await (_database.select(_database.entries)
      ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _fromDbEntry(row);
  }

  Future<List<Entry>> list({String? type, bool includeDeleted = false}) async {
    var query = _database.select(_database.entries);
    if (type != null) {
      query = query..where((t) => t.type.equals(type));
    }
    if (!includeDeleted) {
      query = query..where((t) => t.deletedAt.isNull());
    }
    query = query
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);

    final rows = await query.get();
    return rows.map(_fromDbEntry).toList();
  }

  Future<List<Entry>> search(String query, {int limit = 100}) async {
    final sanitized = query.replaceAll('"', '""');
    final tokens = sanitized.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return [];

    // Prefix match so "git" matches "github", "gitlab", etc.
    final ftsQuery = tokens.map((t) => '$t*').join(' ');

    final rows = await _database.customSelect(
      'SELECT e.* FROM entries e '
      'INNER JOIN entries_fts ON e.id = entries_fts.id '
      'WHERE entries_fts MATCH ? '
      'AND e.deleted_at IS NULL '
      'ORDER BY bm25(entries_fts) '
      'LIMIT ?',
      variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
    ).get();

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row.data);
      return _fromMap(data);
    }).toList();
  }

  Future<void> _syncFts(Entry entry) async {
    if (entry.deletedAt != null) return;

    try {
      await _database.customStatement(
        'DELETE FROM entries_fts WHERE id = ?',
        [entry.id],
      );

      await _database.customInsert(
        'INSERT INTO entries_fts (id, title, content, tags) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(entry.id),
          Variable.withString(entry.title),
          Variable.withString(entry.content),
          Variable.withString(entry.tags.join(' ')),
        ],
      );
    } catch (_) {}
  }

  db.EntriesCompanion _toCompanion(Entry entry) {
    return db.EntriesCompanion(
      id: Value(entry.id),
      type: Value(entry.type.label),
      title: Value(entry.title),
      content: Value(entry.content),
      metadata: Value(jsonEncode(entry.metadata)),
      tags: Value(jsonEncode(entry.tags)),
      tagsColor: entry.tagsColors.isEmpty
          ? const Value(null)
          : Value(jsonEncode(entry.tagsColors)),
      secret: Value(entry.secret),
      requiresAuth: Value(entry.requiresAuth),
      encryptedSecret: Value(entry.encryptedSecret),
      cipherNonce: Value(entry.cipherNonce),
      cipherTag: Value(entry.cipherTag),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(entry.updatedAt),
      version: Value(entry.version),
      deletedAt: Value(entry.deletedAt),
    );
  }

  Entry _fromDbEntry(db.Entry row) {
    return _fromMap({
      'id': row.id,
      'type': row.type,
      'title': row.title,
      'content': row.content,
      'metadata': row.metadata,
      'tags': row.tags,
      'tags_color': row.tagsColor,
      'secret': row.secret,
      'requiresAuth': row.requiresAuth,
      'encryptedSecret': row.encryptedSecret,
      'cipherNonce': row.cipherNonce,
      'cipherTag': row.cipherTag,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'version': row.version,
      'deletedAt': row.deletedAt?.toIso8601String(),
    });
  }

  /// Lee un valor del mapa soportando camelCase y snake_case.
  /// Los raw SQL queries devuelven snake_case, Drift devuelve camelCase.
  T? _val<T>(Map<String, dynamic> data, String camelKey, String snakeKey) {
    return (data[camelKey] ?? data[snakeKey]) as T?;
  }

  /// Lee un String del mapa, soportando camelCase y snake_case.
  String _str(Map<String, dynamic> data, String camelKey, String snakeKey) {
    return (data[camelKey] ?? data[snakeKey]) as String;
  }

  /// Lee un DateTime del mapa.
  /// SQLite raw devuelve int (Unix timestamp), Drift objects devuelven String (ISO 8601).
  DateTime? _dateTimeOrNull(Map<String, dynamic> data, String camelKey, String snakeKey) {
    final raw = data[camelKey] ?? data[snakeKey];
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    if (raw is String) return DateTime.parse(raw);
    return null;
  }

  DateTime _dateTime(Map<String, dynamic> data, String camelKey, String snakeKey) {
    return _dateTimeOrNull(data, camelKey, snakeKey)!;
  }

  bool _bool(Map<String, dynamic> data, String camelKey, String snakeKey) {
    final raw = data[camelKey] ?? data[snakeKey];
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    return false;
  }

  Entry _fromMap(Map<String, dynamic> data) {
    final tagsRaw = _val<String>(data, 'tags', 'tags');
    final tagsColorsRaw = _val<String>(data, 'tagsColors', 'tags_color');
    final metadataRaw = _val<String>(data, 'metadata', 'metadata');

    return Entry(
      id: _str(data, 'id', 'id'),
      type: EntryType.fromLabel(_str(data, 'type', 'type')),
      title: _str(data, 'title', 'title'),
      content: _str(data, 'content', 'content'),
      metadata: metadataRaw != null
          ? Map<String, String>.from(jsonDecode(metadataRaw) as Map)
          : {},
      tags: tagsRaw != null ? List<String>.from(jsonDecode(tagsRaw) as List) : [],
      tagsColors: tagsColorsRaw != null
          ? Map<String, String>.from(jsonDecode(tagsColorsRaw) as Map)
          : {},
      secret: _val<String>(data, 'secret', 'secret'),
      requiresAuth: _bool(data, 'requiresAuth', 'requires_auth'),
      encryptedSecret: _val<String>(data, 'encryptedSecret', 'encrypted_secret'),
      cipherNonce: _val<String>(data, 'cipherNonce', 'cipher_nonce'),
      cipherTag: _val<String>(data, 'cipherTag', 'cipher_tag'),
      createdAt: _dateTime(data, 'createdAt', 'created_at'),
      updatedAt: _dateTime(data, 'updatedAt', 'updated_at'),
      version: _val<int>(data, 'version', 'version') ?? 1,
      deletedAt: _dateTimeOrNull(data, 'deletedAt', 'deleted_at'),
    );
  }
}
