import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'app_database.dart';

class EntryRepositoryImpl implements IEntryRepository {
  final AppDatabase _db;

  EntryRepositoryImpl({required AppDatabase db}) : _db = db;

  @override
  Future<Entry> create(Entry entry) => _db.insertEntry(entry);

  @override
  Future<Entry> getById(String id) async {
    final entry = await _db.getEntry(id);
    if (entry == null) {
      throw EntryNotFoundFailure(message: 'Entry $id not found');
    }
    return entry;
  }

  @override
  Future<List<Entry>> list({
    EntryType? type,
    String? topicKey,
    bool includeDeleted = false,
  }) {
    return _db.listEntries(type: type?.label, includeDeleted: includeDeleted);
  }

  @override
  Future<List<Entry>> search(String query, {int limit = 100}) {
    return _db.searchEntries(query, limit: limit);
  }

  @override
  Future<Entry> update(Entry entry) => _db.updateEntry(entry);

  @override
  Future<void> softDelete(String id) async {
    final entry = await getById(id);
    final updated = entry.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now());
    await _db.updateEntry(updated);
  }

  @override
  Future<void> hardDelete(String id) => _db.deleteEntry(id);
}
