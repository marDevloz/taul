import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';

import 'app_database.dart' as db;

class EntryDao {
  final db.AppDatabase _database;
  final TagSettingsDao _tagSettingsDao;
  final Logger _log = Logger();

  EntryDao(this._database)
      : _tagSettingsDao = TagSettingsDao(_database);

  Future<Entry> insert(Entry entry) async {
    await _database.into(_database.entries).insert(_toCompanion(entry));
    await _syncTags(entry);
    await _syncFts(entry);
    return entry;
  }

  Future<Entry> update(Entry entry) async {
    final companion = _toCompanion(entry);
    await (_database.update(_database.entries)
      ..where((t) => t.id.equals(entry.id)))
        .write(companion);
    await _syncTags(entry);
    await _syncFts(entry);
    return entry;
  }

  /// Batch upsert for sync: pre-fetches all entries in a single query and
  /// uses a Drift batch transaction for inserts/updates.
  Future<void> batchUpsert(List<Entry> entries) async {
    if (entries.isEmpty) return;

    // 1. Pre-fetch existing entries in a single query.
    final ids = entries.map((e) => e.id).toList();
    final existingRows = await (_database.select(_database.entries)
      ..where((tbl) => tbl.id.isIn(ids)))
        .get();
    final existingMap = {
      for (final row in existingRows) row.id: _fromDbEntry(row),
    };

    // 2. Batch DB writes.
    await _database.batch((b) {
      for (final entry in entries) {
        final existing = existingMap[entry.id];
        if (existing == null) {
          b.insert(_database.entries, _toCompanion(entry));
        } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
          b.update(_database.entries, _toCompanion(entry));
        }
      }
    });

    // 3. Side effects (tags, FTS) after the batch.
    for (final entry in entries) {
      final existing = existingMap[entry.id];
      if (existing == null || entry.updatedAt.isAfter(existing.updatedAt)) {
        try {
          await _syncTags(entry);
        } catch (_) {}
        try {
          await _syncFts(entry);
        } catch (_) {}
      }
    }
  }

  /// Removes a tag from all entries that use it. Updates both the JSON tags
  /// column and the FTS index. Does NOT call _syncTags (avoids recreating
  /// a deleted TagSetting). Returns the list of affected entry IDs so callers
  /// can invalidate their detail providers.
  Future<List<String>> removeTagFromAllEntries(String tagName) async {
    final all = await (_database.select(_database.entries)).get();
    final affected = <String>[];
    for (final row in all) {
      final tags = List<String>.from(jsonDecode(row.tags) as List);
      final originalLen = tags.length;
      tags.removeWhere((t) => t.toLowerCase() == tagName.toLowerCase());
      if (tags.length != originalLen) {
        affected.add(row.id);
        await (_database.update(_database.entries)
          ..where((t) => t.id.equals(row.id)))
          .write(db.EntriesCompanion(
            tags: Value(jsonEncode(tags)),
            updatedAt: Value(DateTime.now()),
          ));
        // Update FTS index so search remains accurate
        try {
          await _database.customStatement(
            'DELETE FROM entries_fts WHERE id = ?',
            [row.id],
          );
          await _database.customInsert(
            'INSERT INTO entries_fts (id, title, content, tags) VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString(row.id),
              Variable.withString(row.title),
              Variable.withString(row.content),
              Variable.withString(tags.join(' ')),
            ],
          );
        } catch (_) {}
      }
    }
    return affected;
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

  Future<List<Entry>> list({String? type, bool includeDeleted = false, bool excludeArchived = false}) async {
    var query = _database.select(_database.entries);
    if (type != null) {
      query = query..where((t) => t.type.equals(type));
    }
    if (!includeDeleted) {
      query = query..where((t) => t.deletedAt.isNull());
    }
    if (excludeArchived) {
      query = query..where((t) => t.tags.like('%"archivado"%').not());
    }
    query = query
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);

    final rows = await query.get();
    return rows.map(_fromDbEntry).toList();
  }

  /// Busca entradas cuyo título/contenido/tags coincidan con [query],
  /// acotando el resultado a los filtros activos ([type], [tag],
  /// [completedOnly] y [excludeArchived]) para que la búsqueda respete el
  /// contexto actual de filtrado. El camino FTS5 aplica los filtros en el SQL;
  /// si la extensión no está disponible, el fallback LIKE aplica los mismos
  /// filtros.
  Future<List<Entry>> search(
    String query, {
    int limit = AppConstants.fts5MaxResults,
    String? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) async {
    final sanitized = query.replaceAll('"', '""');
    final tokens = sanitized
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return [];

    try {
      return await _searchFts(
        tokens,
        limit,
        type: type,
        tag: tag,
        completedOnly: completedOnly,
        excludeArchived: excludeArchived,
      );
    } catch (err) {
      if (!_isFtsUnavailableError(err)) rethrow;
      _log.w(
        'FTS5 unavailable, degrading search to LIKE fallback',
        error: err,
      );
      return _searchLike(
        tokens,
        limit,
        type: type,
        tag: tag,
        completedOnly: completedOnly,
        excludeArchived: excludeArchived,
      );
    }
  }

  /// Full-text search via FTS5. Throws when the FTS table is missing or the
  /// FTS5 extension is unavailable (e.g. on Android system SQLite).
  Future<List<Entry>> _searchFts(
    List<String> tokens,
    int limit, {
    String? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) async {
    // Prefix match so "git" matches "github", "gitlab", etc.
    final ftsQuery = tokens.map((t) => '$t*').join(' ');
    final filters = _filterConditions(
      type: type,
      tag: tag,
      completedOnly: completedOnly,
      excludeArchived: excludeArchived,
    );
    final where = [
      'entries_fts MATCH ?',
      'e.deleted_at IS NULL',
      ...filters.conditions,
    ].join(' AND ');

    final rows = await _database.customSelect(
      'SELECT e.* FROM entries e '
      'INNER JOIN entries_fts ON e.id = entries_fts.id '
      'WHERE $where '
      'ORDER BY bm25(entries_fts) '
      'LIMIT ?',
      variables: [
        Variable.withString(ftsQuery),
        ...filters.variables,
        Variable.withInt(limit),
      ],
    ).get();

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row.data);
      return _fromMap(data);
    }).toList();
  }

  /// Cheap degraded search used when FTS5 is unavailable: substring match on
  /// title, content and tags (the same columns the FTS index covers). Every
  /// token must match (AND semantics), mirroring the FTS query. Non-deleted
  /// entries only, most recently updated first, capped by [limit]. The active
  /// filters are applied the same way as in the FTS path.
  Future<List<Entry>> _searchLike(
    List<String> tokens,
    int limit, {
    String? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) async {
    final conditions = <String>[];
    final variables = <Variable>[];
    for (final token in tokens) {
      final pattern = '%${_escapeLikePattern(token)}%';
      conditions.add(
        "(e.title LIKE ? ESCAPE '\\' "
        "OR e.content LIKE ? ESCAPE '\\' "
        "OR e.tags LIKE ? ESCAPE '\\')",
      );
      variables
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern))
        ..add(Variable.withString(pattern));
    }

    final filters = _filterConditions(
      type: type,
      tag: tag,
      completedOnly: completedOnly,
      excludeArchived: excludeArchived,
    );
    final where = [
      'e.deleted_at IS NULL',
      '(${conditions.join(' AND ')})',
      ...filters.conditions,
    ].join(' AND ');

    final rows = await _database.customSelect(
      'SELECT e.* FROM entries e '
      'WHERE $where '
      'ORDER BY e.updated_at DESC '
      'LIMIT ?',
      variables: [...variables, ...filters.variables, Variable.withInt(limit)],
    ).get();

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row.data);
      return _fromMap(data);
    }).toList();
  }

  /// Compiles the SQL conditions of the active filters (type, tag, task
  /// status, archived), mirroring the semantics of `filteredEntriesProvider`:
  /// all filters AND together. The tag match is case-insensitive (SQLite LIKE
  /// is CI by default) over the JSON tags column, same criterion `list()`
  /// uses for archived. `completedOnly == true` restricts to completed tasks,
  /// `false` to pending tasks, `null` leaves the task status open.
  ({List<String> conditions, List<Variable> variables}) _filterConditions({
    String? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) {
    final conditions = <String>[];
    final variables = <Variable>[];

    if (type != null) {
      conditions.add('e.type = ?');
      variables.add(Variable.withString(type));
    }

    if (tag != null && tag.isNotEmpty) {
      conditions.add("e.tags LIKE ? ESCAPE '\\'");
      variables.add(Variable.withString('%"${_escapeLikePattern(tag)}"%'));
    }

    if (completedOnly != null) {
      conditions.add("e.type = '${EntryType.task.label}'");
      conditions.add(
        completedOnly
            ? 'e.completed_at IS NOT NULL'
            : 'e.completed_at IS NULL',
      );
    }

    if (excludeArchived) {
      // Mismo criterio que list(): una entrada está archivada si el tag
      // 'archivado' aparece en su JSON de tags.
      conditions.add("NOT (e.tags LIKE '%\"archivado\"%')");
    }

    return (conditions: conditions, variables: variables);
  }

  /// Detects errors caused by an unavailable FTS5 extension. A missing table
  /// surfaces as "no such table: entries_fts"; a build without the extension
  /// mentions "fts5". Mirrors the heuristic used by ErrorMapper so the same
  /// errors degrade here instead of reaching the UI.
  bool _isFtsUnavailableError(Object err) {
    final lower = err.toString().toLowerCase();
    return lower.contains('entries_fts') || lower.contains('fts5');
  }

  /// Escapes LIKE wildcards so user input is matched literally.
  String _escapeLikePattern(String value) => value.replaceAllMapped(
    RegExp(r'([\\%_])'),
    (m) => '\\${m[1]}',
  );

  /// Sincroniza los tags de un entry a TagSettings para que aparezcan
  /// en la pantalla de Gestión de etiquetas.
  Future<void> _syncTags(Entry entry) async {
    for (final tag in entry.tags) {
      final existing = await _tagSettingsDao.getByName(tag);
      if (existing != null) {
        // Preserve system tag flags — only upsert name to ensure existence
        await _tagSettingsDao.upsert(tag,
            isSystem: existing.isSystem,
            isSecure: existing.isSecure,
            color: existing.color);
      } else {
        await _tagSettingsDao.upsert(tag);
      }
    }
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
      secret: Value(entry.secret),
      requiresAuth: Value(entry.requiresAuth),
      encryptedSecret: Value(entry.encryptedSecret),
      cipherNonce: Value(entry.cipherNonce),
      cipherTag: Value(entry.cipherTag),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(entry.updatedAt),
      version: Value(entry.version),
      deletedAt: Value(entry.deletedAt),
      completedAt: Value(entry.completedAt),
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
      'secret': row.secret,
      'requiresAuth': row.requiresAuth,
      'encryptedSecret': row.encryptedSecret,
      'cipherNonce': row.cipherNonce,
      'cipherTag': row.cipherTag,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'version': row.version,
      'deletedAt': row.deletedAt?.toIso8601String(),
      'completedAt': row.completedAt?.toIso8601String(),
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
      completedAt: _dateTimeOrNull(data, 'completedAt', 'completed_at'),
    );
  }
}
