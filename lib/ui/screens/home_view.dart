import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/quick_add_sheet.dart';
import 'package:taul/ui/widgets/entry_card.dart';
import 'package:taul/ui/widgets/filter_chips.dart';
import 'package:taul/ui/widgets/search_bar_widget.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ],
      ),
      body: Column(
        children: [
          const TaulSearchBar(),
          const SizedBox(height: 8),
          const FilterChipsRow(),
          const SizedBox(height: 8),
          Expanded(
            child: entriesAsync.when(
              data: (entries) => entries.isEmpty
                  ? const Center(
                      child: Text('No entries yet. Tap + to create one.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) => EntryCard(
                        entry: entries[index],
                        onTap: () => _openEntry(context, entries[index].id),
                      ),
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

  void _openEntry(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryDetailView(entryId: id)),
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }
}
