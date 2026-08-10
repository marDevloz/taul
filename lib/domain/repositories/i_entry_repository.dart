import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/search_match.dart';

abstract class IEntryRepository {
  Future<Entry> create(Entry entry);
  Future<Entry> getById(String id);
  Future<List<Entry>> list({
    EntryType? type,
    bool includeDeleted = false,
    bool excludeArchived = false,
  });
  Future<List<Entry>> search(
    String query, {
    int limit = AppConstants.fts5MaxResults,
    EntryType? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  });
  Future<List<SearchMatch>> searchWithSnippets(
    String query, {
    int limit = AppConstants.fts5MaxResults,
    EntryType? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  });
  Future<Entry> update(Entry entry);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
}
