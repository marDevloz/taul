import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/core/errors/error_mapper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/services/merge_service.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/search_match.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/effective_auth_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/screens/create_entry_sheet.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/merge_editor_screen.dart';
import 'package:taul/ui/widgets/empty_states.dart';
import 'package:taul/ui/widgets/entry_card.dart';
import 'package:taul/ui/widgets/master_password_gate.dart';
import 'package:taul/ui/widgets/snake_fab.dart';
import 'package:taul/ui/widgets/search_bar_widget.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  String? _expandedEntryId;
  bool _isSelectMode = false;
  bool _isBatchProcessing = false;
  final Set<String> _selectedEntryIds = {};
  final Set<String> _unlockedEntryIds = {};
  final Map<String, DateTime> _unlockTimestamps = {};
  String? _expandedFabId;
  Timer? _autoLockTimer;
  bool _isFabHovered = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _startAutoLockTimer();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }

  void _startAutoLockTimer() {
    _autoLockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final expired = _unlockTimestamps.entries
          .where((e) => now.difference(e.value).inMinutes >= 1)
          .map((e) => e.key)
          .toList();
      if (expired.isNotEmpty) {
        setState(() {
          for (final id in expired) {
            _unlockedEntryIds.remove(id);
            _unlockTimestamps.remove(id);
          }
        });
      }
    });
  }

  void _unlockEntry(String id) {
    setState(() {
      _unlockedEntryIds.add(id);
      _unlockTimestamps[id] = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for Ctrl+N shortcut events (fired from AppKeyboardShortcuts).
    ref.listen<int>(createEntryEventProvider, (prev, next) {
      if (prev != null && next != prev) {
        _showQuickAdd(context);
      }
    });

    final searchQuery = ref.watch(entrySearchProvider);
    final entriesAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: _isSelectMode ? _buildSelectAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          const TaulSearchBar(),
          const SizedBox(height: 8),
          Expanded(
            child: entriesAsync.when(
              data: (entries) => entries.isEmpty
                  ? _buildEmptyState(context, ref, searchQuery)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        if (width < Breakpoints.mobile) {
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final match = entries[index];
                              final entry = match.entry;
                              return Consumer(
                                builder: (context, ref, _) {
                                  final color = ref.watch(
                                    entryDisplayColorProvider(entry.id),
                                  );
                                  final isSecure = ref.watch(
                                    hasSecureTagProvider(entry.id),
                                  );
                                  final isUnlocked = _unlockedEntryIds.contains(
                                    entry.id,
                                  );
                                  final showLocked = isSecure && !isUnlocked;
                                  final isCredential =
                                      entry.type.label == 'credential';
                                  return EntryCard(
                                    entry: entry,
                                    searchSnippet: match.snippet,
                                    searchTerms: match.terms,
                                    displayColor: color,
                                    isExpanded:
                                        !_isSelectMode &&
                                        _expandedEntryId == entry.id &&
                                        !showLocked,
                                    isSecure: showLocked,
                                    isSelected: _selectedEntryIds.contains(
                                      entry.id,
                                    ),
                                    isFavorito:
                                        entry.tags.contains('favorito'),
                                    isArchivado:
                                        entry.tags.contains('archivado'),
                                    onLongPress: () =>
                                        _enterSelectMode(entry.id),
                                    onToggleCompletado: _isSelectMode
                                        ? null
                                        : () => _toggleCompletado(ref, entry),
                                    onToggleFavorito: _isSelectMode
                                        ? null
                                        : () => _toggleCardFavorito(ref, entry),
                                    onToggleArchivado: _isSelectMode
                                        ? null
                                        : () => _toggleCardArchivado(ref, entry),
                                    onToggle: _isSelectMode
                                        ? () => _toggleSelection(entry.id)
                                        : () {
                                            setState(() {
                                              _expandedEntryId =
                                                  _expandedEntryId == entry.id
                                                  ? null
                                                  : entry.id;
                                            });
                                          },
                                    onTapGated: _isSelectMode
                                        ? null
                                        : () async {
                                            final ok =
                                                await showMasterPasswordGate(
                                                  context: context,
                                                  ref: ref,
                                                );
                                            if (!ok || !context.mounted) return;
                                            if (isCredential) {
                                              _openEntry(context, entry.id);
                                            } else {
                                              _unlockEntry(entry.id);
                                              setState(() {
                                                _expandedEntryId = entry.id;
                                              });
                                            }
                                          },
                                    onDoubleTapGated: _isSelectMode
                                        ? null
                                        : () async {
                                            final ok =
                                                await showMasterPasswordGate(
                                                  context: context,
                                                  ref: ref,
                                                );
                                            if (!ok || !context.mounted) return;
                                            _openEntry(context, entry.id);
                                          },
                                    onTap: _isSelectMode
                                        ? null
                                        : () => _openEntry(context, entry.id),
                                  );
                                },
                              );
                            },
                          );
                        }
                        final crossAxisCount = width < Breakpoints.tablet
                            ? 2
                            : 3;
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 1.8,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final match = entries[index];
                            final entry = match.entry;
                            return Consumer(
                              builder: (context, ref, _) {
                                final color = ref.watch(
                                  entryDisplayColorProvider(entry.id),
                                );
                                final isSecure = ref.watch(
                                  hasSecureTagProvider(entry.id),
                                );
                                final isUnlocked = _unlockedEntryIds.contains(
                                  entry.id,
                                );
                                final showLocked = isSecure && !isUnlocked;
                                final isCredential =
                                    entry.type.label == 'credential';
                                return EntryCard(
                                  entry: entry,
                                  isGrid: true,
                                  searchSnippet: match.snippet,
                                  searchTerms: match.terms,
                                  displayColor: color,
                                  isSecure: showLocked,
                                  isSelected: _selectedEntryIds.contains(
                                    entry.id,
                                  ),
                                  onLongPress: () => _enterSelectMode(entry.id),
                                  onTap: _isSelectMode
                                      ? () => _toggleSelection(entry.id)
                                      : showLocked
                                      ? () async {
                                          final ok =
                                              await showMasterPasswordGate(
                                                context: context,
                                                ref: ref,
                                              );
                                          if (!ok || !context.mounted) return;
                                          if (isCredential) {
                                            _openEntry(context, entry.id);
                                          } else {
                                            _unlockEntry(entry.id);
                                            _openEntry(context, entry.id);
                                          }
                                        }
                                      : () => _openEntry(context, entry.id),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) {
                Logger().e('Home entry list failed', error: err);
                return Center(child: Text(const ErrorMapper().toUserMessage(err)));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: MouseRegion(
        onEnter: (_) => setState(() => _isFabHovered = true),
        onExit: (_) => setState(() => _isFabHovered = false),
        child: AnimatedOpacity(
          opacity: _isMobile
              ? 1.0
              : _isFabHovered
                  ? 1.0
                  : _expandedEntryId != null
                      ? 0.3
                      : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTypeFilterFab(),
              const SizedBox(height: 8),
              _buildTaskStatusFilterFab(),
              const SizedBox(height: 8),
              _buildTagFilterFab(),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: null,
                onPressed: () => _showQuickAdd(context),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterFab() {
    final selectedType = ref.watch(selectedTypeFilterProvider);
    final isExpanded = _expandedFabId == 'type';
    final hasFilter = selectedType != null;

    return SnakeFab(
      isExpanded: isExpanded,
      onTap: () {
        if (hasFilter && !isExpanded) {
          // Toggle off: clear filter directly
          ref.read(selectedTypeFilterProvider.notifier).state = null;
        } else {
          setState(() {
            _expandedFabId = isExpanded ? null : 'type';
          });
        }
      },
      collapsedIcon: Icon(_iconForEntryType(selectedType)),
      items: const [
        SnakeFabItem(value: '', label: 'Todas', icon: Icons.all_inclusive),
        SnakeFabItem(value: 'glossary', label: 'Glosario', icon: Icons.book),
        SnakeFabItem(value: 'note', label: 'Nota', icon: Icons.description),
        SnakeFabItem(value: 'idea', label: 'Idea', icon: Icons.lightbulb),
        SnakeFabItem(
          value: 'credential',
          label: 'Credencial',
          icon: Icons.lock,
        ),
        SnakeFabItem(value: 'task', label: 'Tarea', icon: Icons.checklist),
      ],
      selectedValue: selectedType?.name ?? '',
      onItemSelected: (value) {
        if (value == null || value.isEmpty) {
          ref.read(selectedTypeFilterProvider.notifier).state = null;
        } else {
          ref.read(selectedTypeFilterProvider.notifier).state = EntryType.values
              .firstWhere((e) => e.name == value);
        }
        setState(() => _expandedFabId = null);
      },
    );
  }

  Widget _buildTaskStatusFilterFab() {
    final taskStatus = ref.watch(taskStatusFilterProvider);
    final isExpanded = _expandedFabId == 'task-status';
    final hasFilter = taskStatus != null;

    IconData icon;
    switch (taskStatus) {
      case TaskStatusFilter.pending:
        icon = Icons.hourglass_empty;
      case TaskStatusFilter.completed:
        icon = Icons.check_circle;
      default:
        icon = Icons.task_alt;
    }

    String selectedString;
    switch (taskStatus) {
      case TaskStatusFilter.pending:
        selectedString = 'pending';
      case TaskStatusFilter.completed:
        selectedString = 'completed';
      default:
        selectedString = '';
    }

    return SnakeFab(
      isExpanded: isExpanded,
      onTap: () {
        if (hasFilter && !isExpanded) {
          ref.read(taskStatusFilterProvider.notifier).state = null;
        } else {
          setState(() {
            _expandedFabId = isExpanded ? null : 'task-status';
          });
        }
      },
      collapsedIcon: Icon(icon),
      items: const [
        SnakeFabItem(value: '', label: 'Todas', icon: Icons.all_inclusive),
        SnakeFabItem(value: 'pending', label: 'Pendientes', icon: Icons.hourglass_empty),
        SnakeFabItem(value: 'completed', label: 'Completadas', icon: Icons.check_circle),
      ],
      selectedValue: selectedString,
      onItemSelected: (value) {
        ref.read(taskStatusFilterProvider.notifier).state = switch (value) {
          'pending' => TaskStatusFilter.pending,
          'completed' => TaskStatusFilter.completed,
          _ => null,
        };
        setState(() => _expandedFabId = null);
      },
    );
  }

  Widget _buildTagFilterFab() {
    final tagSettingsAsync = ref.watch(tagSettingsListProvider);
    final tagSettings = tagSettingsAsync.valueOrNull ?? [];
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final tagColors = ref.watch(tagColorMapProvider);
    final isExpanded = _expandedFabId == 'tag';
    final hasFilter = selectedTag != null && selectedTag.isNotEmpty;

    final items = <SnakeFabItem>[
      if (hasFilter)
        const SnakeFabItem(
          value: '',
          label: 'Todas',
          icon: Icons.all_inclusive,
        ),
      for (final tagSetting in tagSettings)
        SnakeFabItem(
          value: tagSetting.name,
          label: tagSetting.name,
          icon: Icons.label,
          color: tagColors[tagSetting.name.toLowerCase()],
        ),
    ];

    return SnakeFab(
      isExpanded: isExpanded,
      onTap: () {
        if (hasFilter && !isExpanded) {
          // Toggle off: clear filter directly
          ref.read(selectedTagFilterProvider.notifier).state = null;
        } else {
          setState(() {
            _expandedFabId = isExpanded ? null : 'tag';
          });
        }
      },
      collapsedIcon: selectedTag != null && selectedTag.isNotEmpty
          ? Icon(Icons.sell, color: tagColors[selectedTag])
          : const Icon(Icons.sell_outlined),
      items: items,
      selectedValue: selectedTag ?? '',
      onItemSelected: (value) {
        if (value == null || value.isEmpty) {
          ref.read(selectedTagFilterProvider.notifier).state = null;
        } else {
          ref.read(selectedTagFilterProvider.notifier).state = value;
        }
        setState(() => _expandedFabId = null);
      },
    );
  }

  IconData _iconForEntryType(EntryType? type) {
    if (type == null) return Icons.filter_list;
    return switch (type) {
      EntryType.glossary => Icons.book,
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.credential => Icons.lock,
      EntryType.task => Icons.checklist,
    };
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    String searchQuery,
  ) {
    if (searchQuery.isNotEmpty) {
      return const EmptyStateSearch();
    }

    final selectedType = ref.watch(selectedTypeFilterProvider);
    if (selectedType != null) {
      return EmptyStateFiltered(type: selectedType);
    }

    return EmptyStateAll(onCreateEntry: () => _showQuickAdd(context));
  }

  void _openEntry(BuildContext context, String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EntryDetailView(entryId: id)));
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateEntrySheet(),
    );
  }

  AppBar _buildNormalAppBar() {
    final excludeArchived = ref.watch(excludeArchivedProvider);
    return AppBar(
      title: GestureDetector(
        onTap: () => _showShortcuts(context),
        child: const Text('Taúl'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Buscar',
          onPressed: () {
            final isOpen = ref.read(isSearchOpenProvider);
            if (isOpen) {
              ref.read(entrySearchProvider.notifier).state = '';
              ref.read(isSearchOpenProvider.notifier).state = false;
            } else {
              ref.read(isSearchOpenProvider.notifier).state = true;
            }
          },
        ),
        IconButton(
          icon: Icon(excludeArchived ? Icons.archive_outlined : Icons.archive),
          tooltip: excludeArchived ? 'Archivados' : 'Ocultar archivados',
          onPressed: () {
            ref.read(excludeArchivedProvider.notifier).state =
                !excludeArchived;
          },
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => context.push('/sync'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Papelera',
          onPressed: () => context.push('/trash'),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.go('/settings'),
        ),
      ],
    );
  }

  AppBar _buildSelectAppBar() {
    final count = _selectedEntryIds.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _isBatchProcessing ? null : _exitSelectMode,
      ),
      title: Text(_isBatchProcessing
          ? 'Procesando...'
          : '$count seleccionados'),
      actions: [
        if (count >= 1) ...[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Mover a la papelera',
            onPressed: _isBatchProcessing ? null : _batchDeleteSelected,
          ),
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            tooltip: 'Favorito',
            onPressed: _isBatchProcessing ? null : () => _batchToggleFavorito(),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archivar',
            onPressed: _isBatchProcessing ? null : () => _batchToggleArchivado(),
          ),
        ],
        if (count >= 2)
          TextButton(
            onPressed: _isBatchProcessing ? null : _navigateToMerge,
            child: const Text('Combinar'),
          ),
      ],
    );
  }

  void _enterSelectMode(String id) {
    setState(() {
      _isSelectMode = true;
      _expandedEntryId = null;
      _selectedEntryIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
        if (_selectedEntryIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedEntryIds.add(id);
      }
    });
  }

  Future<void> _toggleCompletado(WidgetRef ref, Entry entry) async {
    await ref.read(markAsCompletedProvider).call(entry);
    ref.invalidate(entryDetailProvider(entry.id));
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
  }

  Future<void> _toggleCardFavorito(WidgetRef ref, Entry entry) async {
    await ref.read(toggleEntryTagProvider).call(entry, 'favorito');
    ref.invalidate(entryDetailProvider(entry.id));
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
  }

  Future<void> _toggleCardArchivado(WidgetRef ref, Entry entry) async {
    await ref.read(toggleEntryTagProvider).call(entry, 'archivado');
    ref.invalidate(entryDetailProvider(entry.id));
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
  }

  Future<void> _batchToggleFavorito() async {
    final entries = _resolveSelectedEntries();
    final ref = this.ref;
    for (final entry in entries) {
      await ref.read(toggleEntryTagProvider).call(entry, 'favorito');
    }
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
    _exitSelectMode();
  }

  Future<void> _batchToggleArchivado() async {
    final entries = _resolveSelectedEntries();
    final ref = this.ref;
    for (final entry in entries) {
      await ref.read(toggleEntryTagProvider).call(entry, 'archivado');
    }
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
    _exitSelectMode();
  }

  Future<void> _batchDeleteSelected() async {
    final count = _selectedEntryIds.length;
    final noun = count == 1 ? 'entrada' : 'entradas';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover a la papelera'),
        content: Text(
          count == 1
              ? '¿Mover 1 entrada a la papelera? Podés restaurarla después.'
              : '¿Mover $count $noun a la papelera? Podés restaurarlas después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isBatchProcessing = true);

    final ref = this.ref;
    int successCount = 0;
    final totalCount = _selectedEntryIds.length;

    for (final id in _selectedEntryIds.toList()) {
      try {
        await ref.read(deleteEntryProvider).call(id);
        successCount++;
      } catch (e) {
        Logger().e('batchDelete: error for $id', error: e);
      }
    }

    // Provider invalidation cascade
    ref.invalidate(entryListProvider);
    ref.invalidate(filteredEntriesProvider);
    for (final id in _selectedEntryIds) {
      ref.invalidate(entryDetailProvider(id));
    }

    // Exit selection mode
    _exitSelectMode();

    if (!mounted) return;
    setState(() => _isBatchProcessing = false);

    // SnackBar feedback
    final verb = successCount == 1 ? 'movida' : 'movidas';
    if (successCount == totalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount $noun $verb a la papelera')),
      );
    } else if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se movieron $successCount de $totalCount $noun a la papelera',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron mover entradas a la papelera')),
      );
    }
  }

  List<Entry> _resolveSelectedEntries() {
    final matches =
        ref.read(searchResultsProvider).valueOrNull ?? const <SearchMatch>[];
    return matches
        .map((m) => m.entry)
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedEntryIds.clear();
    });
  }

  void _navigateToMerge() {
    if (_selectedEntryIds.length < 2) return;

    // Collect selected entries from the current search results (searchResults
    // includes the filtered list when the search box is empty).
    final matches = ref.read(searchResultsProvider).valueOrNull;
    if (matches == null) return;
    final selected = matches
        .map((m) => m.entry)
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
    if (selected.length < 2) return;

    final mergedText = MergeService.concatenate(selected);
    final navigator = Navigator.of(context);

    navigator
        .push(
          MaterialPageRoute(
            builder: (_) => MergeEditorScreen(
              initialText: mergedText,
              sourceEntries: selected,
            ),
          ),
        )
        .then((saved) {
          if (saved == true) {
            _exitSelectMode();
            // Refresh the list by invalidating providers
            ref.invalidate(entryListProvider);
          }
        });
  }

  void _showShortcuts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ShortcutsSheet(),
    );
  }
}

class _ShortcutsSheet extends StatelessWidget {
  const _ShortcutsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortcuts = [
      ('Ctrl + N', 'Nueva entrada'),
      ('Ctrl + F', 'Buscar'),
      ('Ctrl + ,', 'Configuración'),
      ('Ctrl + Shift + T', 'Papelera'),
      ('Esc', 'Volver al inicio'),
    ];

    final typeHints = [
      ('Texto común', 'Escribí directo'),
      ('!idea', 'Idea'),
      ('Término:def', 'Glosario'),
      ('servicio*user*pass[*url]', 'Credencial'),
      ('[] Tarea', 'Una línea (o varias)'),
      ('-#tag', 'Tags'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.keyboard,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Atajos de teclado', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Generales',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...shortcuts.map(
              (s) => _ShortcutRow(keyCombo: s.$1, description: s.$2),
            ),
            const SizedBox(height: 16),
            Text(
              'Escritura rápida',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...typeHints.map(
              (s) => _ShortcutRow(keyCombo: s.$1, description: s.$2),
            ),
            const SizedBox(height: 12),
            Text(
              'Tocá Taúl de nuevo para cerrar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keyCombo;
  final String description;

  const _ShortcutRow({required this.keyCombo, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              keyCombo,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(description, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
