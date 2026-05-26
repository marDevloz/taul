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
        _showNewEntryOptions(context);
      }
    });

    final searchQuery = ref.watch(entrySearchProvider);
    final entriesAsync = searchQuery.isEmpty
        ? ref.watch(filteredEntriesProvider)
        : ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taúl'),
        actions: [
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
            onPressed: () => context.go('/trash'),
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
          const SizedBox(height: 8),
          const FilterChipsRow(),
          const SizedBox(height: 6),
          const TopicFilterChips(),
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
        onPressed: () => _showNewEntryOptions(context),
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
      onCreateEntry: () => _showNewEntryOptions(context),
    );
  }

  void _openEntry(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryDetailView(entryId: id)),
    );
  }

  void _showNewEntryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Nota, idea o glosario'),
                subtitle: const Text('Texto libre — detecta el tipo automáticamente'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuickAdd(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Credencial'),
                subtitle: const Text('Servicio, usuario y contraseña'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCredentialForm(context);
                },
              ),
            ],
          ),
        ),
      ),
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

  void _showCredentialForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CredentialFormSheet(),
    );
  }
}
