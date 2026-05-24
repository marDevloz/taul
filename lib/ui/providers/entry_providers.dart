import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/create_entry.dart';
import 'package:taul/domain/usecases/delete_entry.dart';
import 'package:taul/domain/usecases/get_entry.dart';
import 'package:taul/domain/usecases/list_entries.dart';
import 'package:taul/domain/usecases/search_entries.dart';
import 'package:taul/domain/usecases/update_entry.dart';
import 'package:taul/infrastructure/database/app_database.dart' as db;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';

// --- Infrastructure providers ---

final databaseProvider = Provider<db.AppDatabase>((ref) => db.AppDatabase());

final daoProvider = Provider<EntryDao>((ref) => EntryDao(ref.watch(databaseProvider)));
final entryAuthServiceProvider = Provider<EntryAuthService>((ref) => EntryAuthService());
final masterPasswordStoreProvider =
    Provider<MasterPasswordStore>((ref) => MasterPasswordStore(ref.watch(databaseProvider)));

final entryRepositoryProvider = Provider<IEntryRepository>((ref) {
  return EntryRepositoryImpl(dao: ref.watch(daoProvider));
});

// --- Use case providers ---

final createEntryProvider = Provider<CreateEntry>((ref) {
  return CreateEntry(repository: ref.watch(entryRepositoryProvider));
});

final getEntryProvider = Provider<GetEntry>((ref) {
  return GetEntry(repository: ref.watch(entryRepositoryProvider));
});

final updateEntryProvider = Provider<UpdateEntry>((ref) {
  return UpdateEntry(repository: ref.watch(entryRepositoryProvider));
});

final deleteEntryProvider = Provider<DeleteEntry>((ref) {
  return DeleteEntry(repository: ref.watch(entryRepositoryProvider));
});

final listEntriesProvider = Provider<ListEntries>((ref) {
  return ListEntries(repository: ref.watch(entryRepositoryProvider));
});

final searchEntriesProvider = Provider<SearchEntries>((ref) {
  return SearchEntries(repository: ref.watch(entryRepositoryProvider));
});

// --- State providers ---

final entryListProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref.watch(listEntriesProvider).call();
});

final entrySearchProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  final query = ref.watch(entrySearchProvider);
  if (query.isEmpty) return ref.watch(entryListProvider.future);
  return ref.watch(searchEntriesProvider).call(query);
});

final selectedTypeFilterProvider = StateProvider<EntryType?>((ref) => null);

final filteredEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  final type = ref.watch(selectedTypeFilterProvider);
  final entries = ref.watch(entryListProvider).valueOrNull ?? [];
  if (type == null) return entries;
  return entries.where((e) => e.type == type).toList();
});

// --- Individual entry ---

final entryDetailProvider = FutureProvider.autoDispose.family<Entry, String>((ref, id) {
  return ref.watch(getEntryProvider).call(id);
});
