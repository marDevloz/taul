import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/domain/services/merge_service.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/effective_auth_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/merge_editor_screen.dart';
import 'package:taul/ui/screens/quick_add_sheet.dart';
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
  final Set<String> _selectedEntryIds = {};
  final Set<String> _unlockedEntryIds = {};
  final Map<String, DateTime> _unlockTimestamps = {};
  String? _expandedFabId;

  @override
  void initState() {
    super.initState();
    _startAutoLockTimer();
  }

  void _startAutoLockTimer() {
    Timer.periodic(const Duration(seconds: 30), (_) {
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
    final entriesAsync = searchQuery.isEmpty
        ? ref.watch(filteredEntriesProvider)
        : ref.watch(searchResultsProvider);

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
                              final entry = entries[index];
                              final color = ref.watch(entryDisplayColorProvider(entry.id));
                              final isSecure = ref.watch(hasSecureTagProvider(entry.id));
                              final isUnlocked = _unlockedEntryIds.contains(entry.id);
                              final showLocked = isSecure && !isUnlocked;
                              final isCredential = entry.type.label == 'credential';
                              return EntryCard(
                                entry: entry,
                                displayColor: color,
                                isExpanded: !_isSelectMode && _expandedEntryId == entry.id && !showLocked,
                                isSecure: showLocked,
                                isSelected: _selectedEntryIds.contains(entry.id),
                                onLongPress: () => _enterSelectMode(entry.id),
                                onToggle: _isSelectMode
                                    ? () => _toggleSelection(entry.id)
                                    : () {
                                        setState(() {
                                          _expandedEntryId = _expandedEntryId == entry.id ? null : entry.id;
                                        });
                                      },
                                onTapGated: _isSelectMode
                                    ? null
                                    : () async {
                                        final ok = await showMasterPasswordGate(context: context, ref: ref);
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
                                        final ok = await showMasterPasswordGate(context: context, ref: ref);
                                        if (!ok || !context.mounted) return;
                                        _openEntry(context, entry.id);
                                      },
                                onTap: _isSelectMode ? null : () => _openEntry(context, entry.id),
                              );
                            },
                          );
                        }
                        final crossAxisCount =
                            width < Breakpoints.tablet ? 2 : 3;
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
                            final entry = entries[index];
                            final color = ref.watch(entryDisplayColorProvider(entry.id));
                            final isSecure = ref.watch(hasSecureTagProvider(entry.id));
                            final isUnlocked = _unlockedEntryIds.contains(entry.id);
                            final showLocked = isSecure && !isUnlocked;
                            final isCredential = entry.type.label == 'credential';
                            return EntryCard(
                              entry: entry,
                              isGrid: true,
                              displayColor: color,
                              isSecure: showLocked,
                              isSelected: _selectedEntryIds.contains(entry.id),
                              onLongPress: () => _enterSelectMode(entry.id),
                              onTap: _isSelectMode
                                  ? () => _toggleSelection(entry.id)
                                  : showLocked
                                      ? () async {
                                          final ok = await showMasterPasswordGate(context: context, ref: ref);
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
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTypeFilterFab(),
          const SizedBox(height: 8),
          _buildTagFilterFab(),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: null,
            onPressed: () => _showQuickAdd(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterFab() {
    final selectedType = ref.watch(selectedTypeFilterProvider);
    final isExpanded = _expandedFabId == 'type';

    return SnakeFab(
      isExpanded: isExpanded,
      onTap: () {
        setState(() {
          _expandedFabId = isExpanded ? null : 'type';
        });
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
      ],
      selectedValue: selectedType?.name ?? '',
      onItemSelected: (value) {
        if (value == null || value.isEmpty) {
          ref.read(selectedTypeFilterProvider.notifier).state = null;
        } else {
          ref.read(selectedTypeFilterProvider.notifier).state =
              EntryType.values.firstWhere((e) => e.name == value);
        }
        setState(() => _expandedFabId = null);
      },
    );
  }

  Widget _buildTagFilterFab() {
    final tags = ref.watch(tagsListProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final tagColors = ref.watch(tagColorMapProvider);
    final isExpanded = _expandedFabId == 'tag';

    final items = <SnakeFabItem>[
      if (selectedTag != null && selectedTag.isNotEmpty)
        const SnakeFabItem(value: '', label: 'Todas', icon: Icons.all_inclusive),
      for (final tag in tags)
        SnakeFabItem(
          value: tag,
          label: tag,
          icon: Icons.label,
          color: tagColors[tag],
        ),
    ];

    return SnakeFab(
      isExpanded: isExpanded,
      onTap: () {
        setState(() {
          _expandedFabId = isExpanded ? null : 'tag';
        });
      },
      collapsedIcon: selectedTag != null && selectedTag.isNotEmpty
          ? Icon(Icons.label, color: tagColors[selectedTag])
          : const Icon(Icons.filter_list),
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
    };
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String searchQuery) {
    if (searchQuery.isNotEmpty) {
      return const EmptyStateSearch();
    }

    final selectedType = ref.watch(selectedTypeFilterProvider);
    if (selectedType != null) {
      return EmptyStateFiltered(type: selectedType);
    }

    return EmptyStateAll(
      onCreateEntry: () => _showQuickAdd(context),
    );
  }

  void _openEntry(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryDetailView(entryId: id)),
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddSheet(
        onCredentialRequested: () => _showCredentialForm(context),
      ),
    );
  }

  Future<void> _showCredentialForm(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CredentialFormSheet(
        onGoBack: () => _showQuickAdd(context),
      ),
    );
  }

  AppBar _buildNormalAppBar() {
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
          icon: const Icon(Icons.sync),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sync coming in Phase 3')),
            );
          },
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
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectMode,
      ),
      title: Text('${_selectedEntryIds.length} seleccionados'),
      actions: [
        TextButton(
          onPressed: _selectedEntryIds.length >= 2 ? _navigateToMerge : null,
          child: const Text('Combinar'),
        ),
        TextButton(
          onPressed: _exitSelectMode,
          child: const Text('Cancelar'),
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

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedEntryIds.clear();
    });
  }

  void _navigateToMerge() {
    if (_selectedEntryIds.length < 2) return;

    // Collect selected entries from the current entries list
    final entriesAsync = ref.read(entrySearchProvider).isEmpty
        ? ref.read(filteredEntriesProvider)
        : ref.read(searchResultsProvider);

    entriesAsync.whenData((entries) {
      final selected = entries
          .where((e) => _selectedEntryIds.contains(e.id))
          .toList();

      if (selected.length < 2) return;

      final mergedText = MergeService.concatenate(selected);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MergeEditorScreen(
            initialText: mergedText,
            sourceEntries: selected,
          ),
        ),
      ).then((saved) {
        if (saved == true) {
          _exitSelectMode();
          // Refresh the list by invalidating providers
          ref.invalidate(entryListProvider);
        }
      });
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
                Icon(Icons.keyboard, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Atajos de teclado', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Text('Generales', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            ...shortcuts.map((s) => _ShortcutRow(keyCombo: s.$1, description: s.$2)),
            const SizedBox(height: 16),
            Text('Escritura rápida', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            ...typeHints.map((s) => _ShortcutRow(keyCombo: s.$1, description: s.$2)),
            const SizedBox(height: 12),
            Text(
              'Tocá Taúl de nuevo para cerrar',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            child: Text(keyCombo, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(description, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
