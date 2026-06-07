import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';

/// Computes effective auth requirement: entry.requiresAuth || any tag is secure
/// Used for credential detail view protection.
final effectiveAuthProvider = Provider.family<bool, String>((ref, entryId) {
  final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
  if (entry == null) return false;
  if (entry.requiresAuth) return true;

  final tagMap = ref.watch(tagSettingsMapProvider);
  for (final tag in entry.tags) {
    final setting = tagMap[tag.toLowerCase()];
    if (setting != null && setting.isSecure) return true;
  }
  return false;
});

/// Checks if an entry has any secure TAG (not credential protection).
/// Used for list view: "protegida" message + password gate.
final hasSecureTagProvider = Provider.family<bool, String>((ref, entryId) {
  final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
  if (entry == null) return false;

  final tagMap = ref.watch(tagSettingsMapProvider);
  for (final tag in entry.tags) {
    final setting = tagMap[tag.toLowerCase()];
    if (setting != null && setting.isSecure) return true;
  }
  return false;
});
