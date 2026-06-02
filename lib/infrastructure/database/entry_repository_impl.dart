import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';

class EntryRepositoryImpl implements IEntryRepository {
  final EntryDao _dao;

  EntryRepositoryImpl({required EntryDao dao}) : _dao = dao;

  @override
  Future<Entry> create(Entry entry) => _dao.insert(entry);

  @override
  Future<Entry> getById(String id) async {
    final entry = await _dao.get(id);
    if (entry == null) {
      throw EntryNotFoundFailure(message: 'Entry $id not found');
    }
    return entry;
  }

  @override
  Future<List<Entry>> list({
    EntryType? type,
    bool includeDeleted = false,
    bool excludeArchived = false,
  }) {
    return _dao.list(
      type: type?.label,
      includeDeleted: includeDeleted,
      excludeArchived: excludeArchived,
    );
  }

  @override
  Future<List<Entry>> search(String query, {int limit = 100}) {
    return _dao.search(query, limit: limit);
  }

  @override
  Future<Entry> update(Entry entry) => _dao.update(entry);

  @override
  Future<void> softDelete(String id) async {
    final entry = await getById(id);
    final updated = entry.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now());
    await _dao.update(updated);
  }

  @override
  Future<void> hardDelete(String id) => _dao.delete(id);
}
