import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'entry_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [EntriesTable, EntriesFtsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  Future<Entry> insertEntry(Entry entry) async {
    final json = _entryToJson(entry);
    await into(entriesTable).insert(json, mode: InsertMode.insert);
    await _syncFts(entry);
    return entry;
  }

  Future<Entry> updateEntry(Entry entry) async {
    final json = _entryToJson(entry);
    await update(entriesTable).replace(json);
    await _syncFts(entry);
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    await (delete(entriesTable)..where((t) => t.id.equals(id))).go();
    await (delete(entriesFtsTable)..where((t) => t.id.equals(id))).go();
  }

  Future<Entry?> getEntry(String id) async {
    final row = await (select(entriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _rowToEntry(row);
  }

  Future<List<Entry>> listEntries({String? type, bool includeDeleted = false}) async {
    var query = select(entriesTable);
    if (type != null) {
      query = query..where((t) => t.type.equals(type));
    }
    if (!includeDeleted) {
      query = query..where((t) => t.deletedAt.isNull());
    }
    query = query..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map(_rowToEntry).toList();
  }

  Future<List<Entry>> searchEntries(String query, {int limit = 100}) async {
    final sanitized = query.replaceAll('"', '""');
    final ftsQuery = '"$sanitized"';

    final rows = await customSelect(
      '''
      SELECT e.* FROM entries e
      INNER JOIN entries_fts fts ON e.id = fts.id
      WHERE entries_fts MATCH ?
      AND e.deleted_at IS NULL
      ORDER BY rank
      LIMIT ?
      ''',
      variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
    ).get();

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row.data);
      return _mapToEntry(data);
    }).toList();
  }

  Future<void> _syncFts(Entry entry) async {
    if (entry.isDeleted) {
      await (delete(entriesFtsTable)..where((t) => t.id.equals(entry.id))).go();
      return;
    }

    await into(entriesFtsTable).insert(
      EntriesFtsTableCompanion(
        id: Value(entry.id),
        title: Value(entry.title),
        content: Value(entry.content),
        tags: Value(entry.tags.join(' ')),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Insertable<EntriesTable> _entryToJson(Entry entry) {
    return EntriesTableCompanion(
      id: Value(entry.id),
      type: Value(entry.type.label),
      title: Value(entry.title),
      content: Value(entry.content),
      metadata: Value(jsonEncode(entry.metadata)),
      tags: Value(jsonEncode(entry.tags)),
      topicKey: Value(entry.topicKey),
      secret: Value(entry.secret),
      createdAt: Value(entry.createdAt),
      updatedAt: Value(entry.updatedAt),
      version: Value(entry.version),
      deletedAt: Value(entry.deletedAt),
    );
  }

  Entry _rowToEntry(EntriesTableData row) {
    return _mapToEntry({
      'id': row.id,
      'type': row.type,
      'title': row.title,
      'content': row.content,
      'metadata': row.metadata,
      'tags': row.tags,
      'topicKey': row.topicKey,
      'secret': row.secret,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'version': row.version,
      'deletedAt': row.deletedAt?.toIso8601String(),
    });
  }

  Entry _mapToEntry(Map<String, dynamic> data) {
    final tagsRaw = data['tags'] as String?;
    final metadataRaw = data['metadata'] as String?;

    return Entry(
      id: data['id'] as String,
      type: EntryType.fromLabel(data['type'] as String),
      title: data['title'] as String,
      content: data['content'] as String,
      metadata: metadataRaw != null ? Map<String, String>.from(jsonDecode(metadataRaw)) : {},
      tags: tagsRaw != null ? List<String>.from(jsonDecode(tagsRaw)) : [],
      topicKey: data['topicKey'] as String?,
      secret: data['secret'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      version: data['version'] as int? ?? 1,
      deletedAt: data['deletedAt'] != null ? DateTime.parse(data['deletedAt'] as String) : null,
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customExecute('''
        CREATE VIRTUAL TABLE entries_fts USING fts5(
          id UNINDEXED,
          title,
          content,
          tags,
          tokenize='unicode61'
        );
      ''');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseName));

    // Enable FTS5
    sqlite3.ensureExtensionLoaded(
      SqliteExtension.fts5,
    );

    return NativeDatabase(file);
  });
}
