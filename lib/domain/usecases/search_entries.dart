import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/search_match.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class SearchEntries {
  final IEntryRepository _repository;

  SearchEntries({required IEntryRepository repository}) : _repository = repository;

  Future<List<Entry>> call(
    String query, {
    int limit = AppConstants.fts5MaxResults,
    EntryType? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) {
    if (query.trim().isEmpty) {
      return Future.value([]);
    }
    return _repository.search(
      query.trim(),
      limit: limit,
      type: type,
      tag: tag,
      completedOnly: completedOnly,
      excludeArchived: excludeArchived,
    );
  }

  /// Igual que [call] pero devuelve también el snippet de contexto y los
  /// términos para resaltar el match en la UI.
  Future<List<SearchMatch>> callWithSnippets(
    String query, {
    int limit = AppConstants.fts5MaxResults,
    EntryType? type,
    String? tag,
    bool? completedOnly,
    bool excludeArchived = false,
  }) {
    if (query.trim().isEmpty) {
      return Future.value([]);
    }
    return _repository.searchWithSnippets(
      query.trim(),
      limit: limit,
      type: type,
      tag: tag,
      completedOnly: completedOnly,
      excludeArchived: excludeArchived,
    );
  }
}
