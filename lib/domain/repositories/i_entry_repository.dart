import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';

abstract class IEntryRepository {
  Future<Entry> create(Entry entry);
  Future<Entry> getById(String id);
  Future<List<Entry>> list({
    EntryType? type,
    bool includeDeleted = false,
    bool excludeArchived = false,
  });
  Future<List<Entry>> search(String query, {int limit = 100});
  Future<Entry> update(Entry entry);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
}
