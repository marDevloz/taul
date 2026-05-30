import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/domain/usecases/get_tag_settings.dart';
import 'package:taul/domain/usecases/save_tag_setting.dart';
import 'package:taul/domain/usecases/delete_tag_setting.dart';
import 'package:taul/ui/providers/entry_providers.dart';

final getTagSettingsProvider = Provider<GetTagSettings>((ref) {
  return GetTagSettings(repository: ref.watch(tagSettingsRepositoryProvider));
});

final saveTagSettingProvider = Provider<SaveTagSetting>((ref) {
  return SaveTagSetting(repository: ref.watch(tagSettingsRepositoryProvider));
});

final deleteTagSettingProvider = Provider<DeleteTagSetting>((ref) {
  return DeleteTagSetting(repository: ref.watch(tagSettingsRepositoryProvider));
});

final tagSettingsListProvider = FutureProvider.autoDispose<List<TagSetting>>((ref) {
  return ref.watch(getTagSettingsProvider).call();
});

/// Canonical tag→color map from tag_settings table (replaces entry-scanned version)
final tagSettingsMapProvider = Provider.autoDispose<Map<String, TagSetting>>((ref) {
  final tags = ref.watch(tagSettingsListProvider).valueOrNull ?? [];
  return {for (final t in tags) t.name: t};
});
