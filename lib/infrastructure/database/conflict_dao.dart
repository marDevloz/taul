import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';

import 'app_database.dart' as db;

class ConflictDao {
  final db.AppDatabase _database;

  ConflictDao(this._database);

  Future<Conflict> insert(Conflict conflict) async {
    final id = await _database.into(_database.conflicts).insert(
          db.ConflictsCompanion(
            entryId: Value(conflict.entryId),
            localVersion: Value(jsonEncode(conflict.localVersion.toJson())),
            remoteVersion: Value(jsonEncode(conflict.remoteVersion.toJson())),
            resolution: Value(conflict.resolution.label),
            peerDeviceId: Value(conflict.peerDeviceId),
            createdAt: Value(conflict.createdAt),
            resolvedAt: Value(conflict.resolvedAt),
          ),
        );
    return conflict.copyWith(id: id);
  }

  Future<void> updateResolution(
      int id, ConflictResolution resolution) async {
    await (_database.update(_database.conflicts)
          ..where((t) => t.id.equals(id)))
        .write(
      db.ConflictsCompanion(
        resolution: Value(resolution.label),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Conflict>> getByResolution(ConflictResolution resolution) async {
    final rows = await (_database.select(_database.conflicts)
          ..where((t) => t.resolution.equals(resolution.label)))
        .get();
    return rows.map(_fromDbConflict).toList();
  }

  Future<List<Conflict>> getByEntryId(String entryId) async {
    final rows = await (_database.select(_database.conflicts)
          ..where((t) => t.entryId.equals(entryId)))
        .get();
    return rows.map(_fromDbConflict).toList();
  }

  Future<int> getPendingCount() async {
    final query = _database.selectOnly(_database.conflicts)
      ..addColumns([_database.conflicts.id.count()])
      ..where(_database.conflicts.resolution
          .equals(ConflictResolution.pending.label));
    final result = await query.getSingle();
    return result.read(_database.conflicts.id.count()) ?? 0;
  }

  Conflict _fromDbConflict(db.Conflict row) {
    return Conflict(
      id: row.id,
      entryId: row.entryId,
      localVersion: Entry.fromJson(
          jsonDecode(row.localVersion) as Map<String, dynamic>),
      remoteVersion: Entry.fromJson(
          jsonDecode(row.remoteVersion) as Map<String, dynamic>),
      resolution: ConflictResolution.fromLabel(row.resolution),
      peerDeviceId: row.peerDeviceId,
      createdAt: row.createdAt,
      resolvedAt: row.resolvedAt,
    );
  }
}