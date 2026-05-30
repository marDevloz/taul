import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/quick_add_sheet.dart';
import 'package:taul/ui/widgets/empty_states.dart';
import 'package:taul/ui/widgets/entry_card.dart';
import 'package:taul/ui/widgets/filter_chips.dart';
import 'package:taul/ui/widgets/search_bar_widget.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBar: AppBar(
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
      ),
      body: Column(
        children: [
          const TaulSearchBar(),
          const FilterChipsRow(),
          const TagFilterRow(),
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
                            itemBuilder: (context, index) => EntryCard(
                              entry: entries[index],
                              onTap: () => _openEntry(context, entries[index].id),
                            ),
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
                          itemBuilder: (context, index) => EntryCard(
                            entry: entries[index],
                            isGrid: true,
                            onTap: () => _openEntry(context, entries[index].id),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAdd(context),
        child: const Icon(Icons.add),
      ),
    );
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
