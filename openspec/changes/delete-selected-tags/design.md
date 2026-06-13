# Design: Delete Selected Tags

## Architecture Decision

### Selection State: Local Widget State
- `_selectedTags` is a `Set<String>` stored in stateful widget state (`_TagManagementScreenState`)
- **Why local**: Selection is purely a UI concern — it only affects rendering of the current screen. No other screen or provider needs to know about it. Introducing a Riverpod provider would add unnecessary indirection and invalidation complexity for ephemeral UI state.
- **Trade-off accepted**: On hot reload or widget rebuild from ancestor provider change, selection is lost. This is acceptable because selection is a transient interaction (see spec: "Selection persistence across screen revisits" is explicitly out of scope).

### Widget Type Change: ConsumerWidget → ConsumerStatefulWidget
- `TagManagementScreen` must change from `ConsumerWidget` to `ConsumerStatefulWidget` to hold `_selectedTags` state.
- `_TagManagementScreenState` will hold:
  - `Set<String> _selectedTags = {}`
  - Computed getter `bool get _isSelectionMode => _selectedTags.isNotEmpty`

### Reuse Existing Use Cases
- No new domain or infrastructure code. Batch delete iterates over selected tags and calls the same `deleteTagSettingProvider` and `removeTagFromEntriesProvider` used by single-tag delete.
- **Why a loop**: The existing use cases are simple repository calls with no batch API. Adding a batch use case would add domain complexity for no benefit — the loop is O(N) where N is typically < 20 tags.

---

## Component Changes

### 1. TagManagementScreen (lib/ui/screens/tag_management_screen.dart)

#### Conversion to StatefulWidget

```dart
// Before:
class TagManagementScreen extends ConsumerWidget { ... }

// After:
class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});
  @override
  ConsumerState<TagManagementScreen> createState() => _TagManagementScreenState();
}
```

#### State: _TagManagementScreenState

```dart
class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  final Set<String> _selectedTags = {};

  bool get _isSelectionMode => _selectedTags.isNotEmpty;

  void _toggleSelection(String tagName) {
    setState(() {
      if (_selectedTags.contains(tagName)) {
        _selectedTags.remove(tagName);
      } else {
        _selectedTags.add(tagName);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedTags.clear());
  }
}
```

#### build() Method Changes

**AppBar**: When in selection mode, replace the title and actions:
- Title: `"${_selectedTags.length} seleccionado(s)"`
- No add button (add is hidden during selection)
- Back button exits selection mode via `_clearSelection()`

```dart
appBar: AppBar(
  title: Text(_isSelectionMode
      ? '${_selectedTags.length} seleccionado${_selectedTags.length == 1 ? '' : 's'}'
      : 'Gestionar etiquetas'),
  actions: _isSelectionMode
      ? []
      : [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar etiqueta',
            onPressed: () => _showAddTagDialog(context, ref),
          ),
        ],
  leading: _isSelectionMode
      ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        )
      : null, // keep default back arrow when not in selection
),
```

**Body**: Wrap the existing ListView in a `Stack` to overlay the action bar at the bottom:

```dart
body: Stack(
  children: [
    tagsAsync.when(
      data: (tags) { /* existing ListView logic */ },
      loading: /* existing */,
      error: /* existing */,
    ),
    if (_isSelectionMode)
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _DeleteActionBar(
          selectedCount: _selectedTags.length,
          onDelete: _showBatchDeleteConfirmation,
          onCancel: _clearSelection,
        ),
      ),
  ],
),
```

**Tag Tile Passing**: Pass selection state down to `_TagSettingTile`:
- Already receives `setting` and `isSystem`
- Add: `isSelected: bool`, `isSelectionMode: bool`, `onToggle: VoidCallback`

```dart
_TagSettingTile(
  setting: tag,
  ref: ref,
  isSystem: false,
  isSelected: _selectedTags.contains(tag.name),
  isSelectionMode: _isSelectionMode,
  onToggle: () => _toggleSelection(tag.name),
)
```

#### New Methods

```dart
Future<void> _showBatchDeleteConfirmation() async {
  final counts = ref.read(tagUsageCountProvider);
  int totalAffectedEntries = 0;
  for (final name in _selectedTags) {
    totalAffectedEntries += counts[name.toLowerCase()] ?? 0;
  }

  final count = _selectedTags.length;
  final tagLabel = count == 1 ? 'tag' : 'tags';
  final entryLabel = totalAffectedEntries == 1 ? 'entrada' : 'entradas';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(count == 1 ? '¿Eliminar tag?' : '¿Eliminar tags?'),
      content: Text(
        'Se eliminará$tagLabel $count $tagLabel y se desvinculará$tagLabel '
        'de $totalAffectedEntries $entryLabel.',
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

  if (confirmed == true && context.mounted) {
    await _executeBatchDelete();
  }
  // If cancelled, stay in selection mode (don't call _clearSelection)
}

Future<void> _executeBatchDelete() async {
  final deleteUseCase = ref.read(deleteTagSettingProvider);
  final removeTag = ref.read(removeTagFromEntriesProvider);
  final affectedEntryIds = <String>{};
  int successCount = 0;
  final totalCount = _selectedTags.length;

  for (final tagName in _selectedTags.toList()) {
    try {
      await deleteUseCase.call(tagName);
      final ids = await removeTag(tagName);
      affectedEntryIds.addAll(ids);
      successCount++;
    } catch (e) {
      // Log error, continue with next tag
    }
  }

  // Provider invalidation cascade
  ref.invalidate(tagSettingsListProvider);
  ref.invalidate(entryListProvider);
  for (final id in affectedEntryIds) {
    ref.invalidate(entryDetailProvider(id));
  }

  // Exit selection
  _clearSelection();

  // SnackBar
  if (!context.mounted) return;
  if (successCount == totalCount) {
    final label = totalCount == 1 ? 'tag' : 'tags';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$totalCount $label eliminados')),
    );
  } else if (successCount > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Se eliminaron $successCount de $totalCount tags'),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudieron eliminar tags')),
    );
  }
}
```

---

### 2. _TagSettingTile Modifications (lib/ui/screens/tag_management_screen.dart)

#### New Constructor Parameters

```dart
class _TagSettingTile extends ConsumerWidget {
  final TagSetting setting;
  final WidgetRef ref;
  final bool isSystem;
  final bool isSelected;       // NEW
  final bool isSelectionMode;  // NEW
  final VoidCallback? onToggle; // NEW

  const _TagSettingTile({
    required this.setting,
    required this.ref,
    this.isSystem = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggle,
  });
}
```

#### Behavior Matrix

| Tag Type | Mode | Tap | Long-press |
|----------|------|-----|------------|
| User | Normal | Rename dialog (existing) | Enter selection, select this tag |
| User | Selection | Toggle selection | Toggle selection |
| System | Any | Color picker (existing) | No-op (existing) |

#### build() Logic — User Tag

```dart
if (isSelectionMode || _selectedTags.isNotEmpty) {
  return ListTile(
    leading: Stack(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 16,
          child: setting.isSecure
              ? const Icon(Icons.lock, size: 16, color: Colors.white)
              : null,
        ),
        if (isSelected)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(1),
              child: Icon(Icons.check_circle,
                  size: 14, color: Theme.of(context).colorScheme.primary),
            ),
          ),
      ],
    ),
    title: Text(setting.name),
    onTap: onToggle,
    onLongPress: onToggle,
  );
}
```

#### build() Logic — System Tag (unchanged)

System tags remain exactly as they are: no selection, no checkbox, no long-press interaction. Their `onTap` stays as color picker, no change needed.

---

### 3. _DeleteActionBar (lib/ui/screens/tag_management_screen.dart)

New private `StatelessWidget` at file bottom:

```dart
class _DeleteActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _DeleteActionBar({
    required this.selectedCount,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Selection count
          Expanded(
            child: Text(
              selectedCount == 1
                  ? '1 tag seleccionado'
                  : '$selectedCount tags seleccionados',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            tooltip: 'Cancelar selección',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            color: theme.colorScheme.error,
            onPressed: onDelete,
            tooltip: 'Eliminar seleccionados',
          ),
        ],
      ),
    );
  }
}
```

---

## Data Flow

```
Long-press user tag
  → _toggleSelection(tagName)
  → setState → _isSelectionMode == true
  → AppBar switches to selection mode
  → Action bar appears
  → Tag tiles show checkboxes

Tap delete in action bar
  → _showBatchDeleteConfirmation()
  → AlertDialog with count + entry effects
  → Confirm → _executeBatchDelete()

_executeBatchDelete()
  for each tagName in _selectedTags:
    1. await deleteTagSettingProvider(tagName)
    2. await removeTagFromEntriesProvider(tagName)
    3. collect affectedEntryIds
  deduplicate affectedEntryIds
  invalidate tagSettingsListProvider
  invalidate entryListProvider
  invalidate entryDetailProvider(id) for each unique id
  _clearSelection()
  show SnackBar
```

---

## Provider Invalidation Order

1. `tagSettingsListProvider` — tag list refreshes (deleted tags gone)
2. `entryListProvider` — entry list reflects unlinked tags
3. `entryDetailProvider(id)` — per entry view reflects unlinked tags

No need to invalidate `tagSettingsMapProvider` or `tagUsageCountProvider` — they are auto-dispose providers that derive from `tagSettingsListProvider` and `entryListProvider` respectively, so they recompute automatically when their dependencies invalidate.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/ui/screens/tag_management_screen.dart` | Main changes: convert to StatefulWidget, selection state, action bar, batch delete flow |
| `test/ui/screens/tag_management_screen_test.dart` | Add tests for selection mode, action bar, batch delete |

No new files needed. No domain or infrastructure changes.

---

## Testing Strategy

### Widget Tests (tag_management_screen_test.dart)

| Test | Description |
|------|-------------|
| `should_enter_selection_mode_on_long_press` | Long-press user tag → selected tag visible, action bar appears |
| `should_toggle_selection_on_tap_in_selection_mode` | Tap tag while in selection → toggles its selected state |
| `should_not_select_system_tags` | Tap system tag in selection mode → no selection change |
| `should_exit_selection_via_back_button` | Tap close icon in app bar → selection cleared, normal UI |
| `should_exit_selection_on_last_deselect` | Deselect last tag → exits selection mode automatically |
| `should_update_count_in_action_bar` | Select 1 → "1 tag seleccionado"; select 2 → "2 tags seleccionados" |
| `should_hide_action_bar_on_cancel` | Tap cancel in action bar → selection cleared, bar gone |
| `should_show_batch_confirmation` | Tap delete in action bar → confirmation dialog appears |
| `should_stay_in_selection_on_cancel_confirmation` | Cancel in confirmation → stays in selection mode |
| `should_show_snackbar_on_batch_delete` | Confirm deletion → SnackBar "N tags eliminados" |

### Integration / Manual Test

- Full flow: long-press → select multiple → confirm → providers invalidate → list updated → SnackBar
- Partial success: mock one delete to throw → verify SnackBar shows partial count
- All fail: mock all deletes to throw → verify SnackBar "No se pudieron eliminar tags"
