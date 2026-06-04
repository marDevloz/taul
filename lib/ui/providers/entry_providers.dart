import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/services/master_password_recovery_service.dart';
import 'package:taul/domain/usecases/create_entry.dart';
import 'package:taul/domain/usecases/delete_entry.dart';
import 'package:taul/domain/usecases/empty_trash.dart';
import 'package:taul/domain/usecases/get_entry.dart';
import 'package:taul/domain/usecases/list_entries.dart';
import 'package:taul/domain/usecases/mark_as_completed.dart';
import 'package:taul/domain/usecases/restore_entry.dart';
import 'package:taul/domain/usecases/search_entries.dart';
import 'package:taul/domain/usecases/toggle_entry_tag.dart';
import 'package:taul/domain/usecases/update_entry.dart';
import 'package:taul/infrastructure/database/app_database.dart' as db;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';
import 'package:taul/infrastructure/database/tag_settings_repository_impl.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/infrastructure/export/export_service.dart';
import 'package:taul/infrastructure/export/import_service.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';

// --- App lock state ---

enum AppLockStatus { unlocked, locked, checking }

class AppLockNotifier extends StateNotifier<AppLockStatus> {
  AppLockNotifier(this._ref) : super(AppLockStatus.checking) {
    _checkInitialStatus();
  }

  final Ref _ref;

  Future<void> _checkInitialStatus() async {
    try {
      final config = await _ref.read(masterPasswordStoreProvider).readFull();
      final isConfigured = config != null &&
          config.encryptedStorageKeyHex != null &&
          config.encryptedStorageKeyHex!.isNotEmpty;

      final prefs = await SharedPreferences.getInstance();
      final appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

      state = (isConfigured && appLockEnabled) ? AppLockStatus.locked : AppLockStatus.unlocked;
    } catch (_) {
      state = AppLockStatus.unlocked;
    }
  }

  void unlock() => state = AppLockStatus.unlocked;
  void lock() => state = AppLockStatus.locked;
}

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockStatus>((ref) {
  return AppLockNotifier(ref);
});

/// Toggle for the optional general lock on startup.
class AppLockEnabledNotifier extends StateNotifier<bool> {
  AppLockEnabledNotifier() : super(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('app_lock_enabled') ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
  }
}

final appLockEnabledProvider = StateNotifierProvider<AppLockEnabledNotifier, bool>((ref) {
  final notifier = AppLockEnabledNotifier();
  notifier.load();
  return notifier;
});

// --- Master password key cache (volatile, in-memory) ---

class MasterPasswordNotifier extends StateNotifier<Uint8List?> {
  MasterPasswordNotifier() : super(null);

  Uint8List? get cachedKey => state;
  void setMasterPassword(Uint8List key) => state = key;
  void clearMasterPassword() => state = null;
  bool get isSet => state != null;
}

final masterPasswordProvider =
    StateNotifierProvider<MasterPasswordNotifier, Uint8List?>((ref) {
  return MasterPasswordNotifier();
});

// --- Infrastructure providers ---

final databaseProvider = Provider<db.AppDatabase>((ref) => db.AppDatabase());

final daoProvider = Provider<EntryDao>((ref) => EntryDao(ref.watch(databaseProvider)));
final entryAuthServiceProvider = Provider<EntryAuthService>((ref) => EntryAuthService());
final masterPasswordStoreProvider =
    Provider<MasterPasswordStore>((ref) => MasterPasswordStore(ref.watch(databaseProvider)));

final credentialProtectionControllerProvider =
    Provider<CredentialProtectionController>((ref) {
  return CredentialProtectionController(
    authService: ref.watch(entryAuthServiceProvider),
    passwordStore: ref.watch(masterPasswordStoreProvider),
    masterPasswordNotifier: ref.watch(masterPasswordProvider.notifier),
  );
});

final entryRepositoryProvider = Provider<IEntryRepository>((ref) {
  return EntryRepositoryImpl(dao: ref.watch(daoProvider));
});

final tagSettingsDaoProvider = Provider<TagSettingsDao>((ref) {
  return TagSettingsDao(ref.watch(databaseProvider));
});

final tagSettingsRepositoryProvider = Provider<ITagSettingsRepository>((ref) {
  return TagSettingsRepositoryImpl(dao: ref.watch(tagSettingsDaoProvider));
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(repository: ref.watch(entryRepositoryProvider));
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

final restoreEntryProvider = Provider<RestoreEntry>((ref) {
  return RestoreEntry(repository: ref.watch(entryRepositoryProvider));
});

final emptyTrashProvider = Provider<EmptyTrash>((ref) {
  return EmptyTrash(repository: ref.watch(entryRepositoryProvider));
});

final listEntriesProvider = Provider<ListEntries>((ref) {
  return ListEntries(repository: ref.watch(entryRepositoryProvider));
});

final searchEntriesProvider = Provider<SearchEntries>((ref) {
  return SearchEntries(repository: ref.watch(entryRepositoryProvider));
});

final markAsCompletedProvider = Provider<MarkAsCompleted>((ref) {
  return MarkAsCompleted(repository: ref.watch(entryRepositoryProvider));
});

final toggleEntryTagProvider = Provider<ToggleEntryTag>((ref) {
  return ToggleEntryTag(repository: ref.watch(entryRepositoryProvider));
});

// --- State providers ---

final entryListProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  final excludeArchived = ref.watch(excludeArchivedProvider);
  return ref.watch(listEntriesProvider).call(excludeArchived: excludeArchived);
});

/// Lista ordenada de IDs de entradas visibles, para navegación
/// anterior/siguiente en la pantalla de detalle.
final entryIdListProvider = Provider.autoDispose<List<String>>((ref) {
  final entries = ref.watch(entryListProvider).valueOrNull ?? [];
  return entries.map((e) => e.id).toList();
});

final trashListProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref.watch(listEntriesProvider).call(includeDeleted: true).then(
    (entries) => entries.where((e) => e.isDeleted).toList(),
  );
});

final entrySearchProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  final query = ref.watch(entrySearchProvider);
  if (query.isEmpty) return ref.watch(entryListProvider.future);
  return ref.watch(searchEntriesProvider).call(query);
});

final selectedTypeFilterProvider = StateProvider<EntryType?>((ref) => null);

enum TaskStatusFilter { pending, completed }

/// Estado de completitud para filtrar tareas. `null` = mostrar todas.
final taskStatusFilterProvider = StateProvider<TaskStatusFilter?>((ref) => null);

/// Tag seleccionado para filtrar. `null` = mostrar todos.
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);

/// Whether to exclude archived entries from the main list.
final excludeArchivedProvider = StateProvider<bool>((ref) => false);

/// Todos los tags únicos de entradas no eliminadas.
/// Ordenados por frecuencia de uso (más usado primero).
final tagsListProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(entryListProvider).valueOrNull ?? [];
  final freq = <String, int>{};
  for (final e in entries) {
    for (final tag in e.tags) {
      final lower = tag.toLowerCase();
      freq[lower] = (freq[lower] ?? 0) + 1;
    }
  }
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.map((e) => e.key).toList();
});

final filteredEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  final type = ref.watch(selectedTypeFilterProvider);
  final tag = ref.watch(selectedTagFilterProvider);
  final taskStatus = ref.watch(taskStatusFilterProvider);
  final entries = ref.watch(entryListProvider).valueOrNull ?? [];
  var result = entries;
  if (type != null) {
    result = result.where((e) => e.type == type).toList();
  }
  if (tag != null && tag.isNotEmpty) {
    result = result.where((e) => e.tags.any((t) => t.toLowerCase() == tag.toLowerCase())).toList();
  }
  if (taskStatus == TaskStatusFilter.pending) {
    result = result.where((e) => e.type == EntryType.task && e.completedAt == null).toList();
  } else if (taskStatus == TaskStatusFilter.completed) {
    result = result.where((e) => e.type == EntryType.task && e.completedAt != null).toList();
  }
  return result;
});

// --- Full config provider for reactive UI ---

/// Provides the full master password config for reactive UI updates.
final masterPasswordConfigProvider =
    FutureProvider<MasterPasswordFullConfig?>((ref) {
  return ref.watch(masterPasswordStoreProvider).readFull();
});

/// Counts entries with `requiresAuth = true` for the delete-MP warning.
final protectedEntryCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.customSelect(
    'SELECT COUNT(*) as cnt FROM entries WHERE requires_auth = 1 AND deleted_at IS NULL',
  ).get();
  return (rows.first.data['cnt'] as int?) ?? 0;
});

// --- Master password recovery providers ---

/// Provides the domain service for MP setup, change, and recovery operations.
final recoveryServiceProvider = Provider<MasterPasswordRecoveryService>((ref) {
  return MasterPasswordRecoveryService(
    authService: ref.watch(entryAuthServiceProvider),
  );
});

/// Reads the optional password hint from the DB (reactive via config provider).
final masterPasswordHintProvider = FutureProvider<String?>((ref) {
  ref.watch(masterPasswordConfigProvider); // dependency for invalidation cascade
  return ref.watch(masterPasswordStoreProvider).readHint();
});

/// Checks whether a master password is configured (has encrypted storage key).
final masterPasswordStatusProvider = FutureProvider<bool>((ref) {
  ref.watch(masterPasswordConfigProvider); // dependency for invalidation cascade
  return ref.watch(masterPasswordStoreProvider).readFull().then((config) {
    return config != null &&
        config.encryptedStorageKeyHex != null &&
        config.encryptedStorageKeyHex!.isNotEmpty;
  });
});

// --- Individual entry ---

final entryDetailProvider = FutureProvider.autoDispose.family<Entry, String>((ref, id) {
  return ref.watch(getEntryProvider).call(id);
});

// --- Search bar state ---

/// Tracks whether the search input is visible.
/// The icon sits in AppBar.actions; when tapped, this becomes `true`
/// and the TextField appears below.
final isSearchOpenProvider = StateProvider<bool>((ref) => false);

/// Set to `true` to request focus on the search bar.
/// The search bar widget resets it to `false` after focusing.
final focusSearchProvider = StateProvider<bool>((ref) => false);

// --- Keyboard shortcut event providers ---

/// Increment to trigger a "create new entry" event.
/// HomeView listens to this and opens the new-entry options.
final createEntryEventProvider = StateProvider<int>((ref) => 0);
