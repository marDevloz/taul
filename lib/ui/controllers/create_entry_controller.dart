import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/usecases/create_entry.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';

part 'create_entry_controller.freezed.dart';

// ---------------------------------------------------------------------------
// CreateEntryState — mutable state for the entry creation sheet
// ---------------------------------------------------------------------------

@freezed
class CreateEntryState with _$CreateEntryState {
  const CreateEntryState._();

  const factory CreateEntryState({
    required String title,
    required String content,
    required String tags,
    EntryType? detectedType,
    EntryType? manualType,
    @Default(false) bool isSaving,
    String? error,
  }) = _CreateEntryState;

  /// Computed: manual overrides detected, falls back to note.
  EntryType get effectiveType => manualType ?? detectedType ?? EntryType.note;

  /// True when the user has explicitly set a type.
  bool get isManual => manualType != null;
}

// ---------------------------------------------------------------------------
// ProcessedContent — result of formatting body content per EntryType
// ---------------------------------------------------------------------------

@freezed
class ProcessedContent with _$ProcessedContent {
  const factory ProcessedContent({
    required String content,
    @Default(<String, String>{}) Map<String, String> metadata,
    String? secret,
    @Default(false) bool requiresAuth,
    @Default(<String>[]) List<String> tags,
  }) = _ProcessedContent;
}

// ---------------------------------------------------------------------------
// CreateEntryController — orchestration for entry creation
// ---------------------------------------------------------------------------

class CreateEntryController extends StateNotifier<CreateEntryState> {
  CreateEntryController({
    required CreateEntry createEntry,
    required EntryDraftNotifier draftNotifier,
    required Ref ref,
  })  : _createEntry = createEntry,
        _draftNotifier = draftNotifier,
        _ref = ref,
        super(const CreateEntryState(
          title: '',
          content: '',
          tags: '',
        ));

  final CreateEntry _createEntry;
  final EntryDraftNotifier _draftNotifier;
  final Ref _ref;

  // ---------------------------------------------------------------------------
  // Static helpers (ported identically from CreateEntrySheet)
  // ---------------------------------------------------------------------------

  /// Busca "Title# " al inicio del texto y devuelve title + el resto.
  /// El separador es `#` solo — tags ahora usan `-#` así que no hay colisión.
  static ({String title, String rest}) splitTitle(String raw) {
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '#' && i + 1 < raw.length && raw[i + 1] == ' ') {
        return (
          title: raw.substring(0, i).trim(),
          rest: raw.substring(i + 1).trim(),
        );
      }
    }
    return (title: '', rest: raw);
  }

  /// Extrae los `-#tag` de un texto y devuelve el texto limpio + los tags.
  static ({String clean, List<String> tags}) extractTags(String raw) =>
      RichTextHelper.extractTags(raw);

  /// Strips both the `Title# ` prefix and `-#tag` markers from the rich text
  /// content. Used by note and fallback-credential cases where the content
  /// is stored as Delta JSON and the title prefix must not appear in the body.
  /// Order matters: strip title prefix FIRST, then strip tags.
  static String stripTitleAndTags(
    String deltaJson,
    List<String> tags,
    String titlePrefix,
  ) {
    var stripped = deltaJson;
    if (titlePrefix.isNotEmpty) {
      stripped = RichTextHelper.stripPrefix(stripped, '$titlePrefix# ');
    }
    stripped = RichTextHelper.stripTagsFromContent(stripped, tags);
    return stripped;
  }

  // ---------------------------------------------------------------------------
  // Type detection from content
  // ---------------------------------------------------------------------------

  /// Updates [content] and [detectedType] from Delta JSON content.
  /// Detección optimista: un solo carácter ya sugiere el tipo.
  /// Si el siguiente carácter no encaja, se actualiza naturalmente.
  void detectTypeFromContent(String jsonContent) {
    if (jsonContent.isEmpty) {
      state = state.copyWith(content: jsonContent, detectedType: null);
      return;
    }
    try {
      final plainText = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(jsonContent),
      ).trim();
      if (plainText.isEmpty) {
        state = state.copyWith(content: jsonContent, detectedType: null);
        return;
      }

      EntryType? detected;

      // Ignorar Title# prefix para detecciones
      final text = plainText;
      final rest = splitTitle(text).rest;

      if (text.startsWith('!')) {
        detected = EntryType.idea;
      } else if (rest.startsWith('[') || rest.startsWith('[]')) {
        detected = EntryType.task;
      } else if (rest.contains('*')) {
        detected = EntryType.credential;
      } else if (rest.contains(':') && !rest.contains('://')) {
        detected = EntryType.glossary;
      } else {
        detected = EntryType.note;
      }

      state = state.copyWith(content: jsonContent, detectedType: detected);
    } catch (_) {
      state = state.copyWith(content: jsonContent);
    }
  }

  // ---------------------------------------------------------------------------
  // Content formatting per entry type
  // ---------------------------------------------------------------------------

  /// Formats body content according to EntryType rules.
  /// Returns both the [ProcessedContent] and the [EntryType] (may change
  /// from the input type, e.g. credential → note when parsing fails).
  /// Pure function — does NOT mutate state.
  ({ProcessedContent content, EntryType type}) processContentForType(
    EntryType type,
    String body,
    String title,
    List<String> tags,
  ) {
    switch (type) {
      case EntryType.idea:
        return (
          content: ProcessedContent(
            content: body.startsWith('!') ? body.substring(1).trim() : body,
            tags: tags,
          ),
          type: type,
        );
      case EntryType.glossary:
        return (
          content: ProcessedContent(
            content: RichTextHelper.formatForGlossary(body),
            tags: tags,
          ),
          type: type,
        );
      case EntryType.credential:
        final parsedCred = CredentialParser.parse(body);
        if (parsedCred != null) {
          final metadata = <String, String>{
            if (parsedCred.username.isNotEmpty) 'username': parsedCred.username,
            if (parsedCred.url.isNotEmpty) 'url': parsedCred.url,
          };
          final mergedTags = [
            ...tags,
            ...parsedCred.tags.where((t) => !tags.contains(t)),
          ];
          return (
            content: ProcessedContent(
              content: parsedCred.username.isNotEmpty
                  ? 'Usuario: ${parsedCred.username}'
                  : parsedCred.service,
              metadata: metadata,
              secret: parsedCred.password,
              requiresAuth: true,
              tags: mergedTags,
            ),
            type: type,
          );
        }
        // No se pudo parsear como credencial — fallback a nota
        return (
          content: ProcessedContent(
            content: stripTitleAndTags(body, tags, title),
            tags: tags,
          ),
          type: EntryType.note,
        );
      case EntryType.task:
        var content = stripTitleAndTags(body, tags, title);
        if (RichTextHelper.startsWithTaskMarker(body)) {
          final plainPrefix = body.substring(
            0,
            body.length - RichTextHelper.stripTaskMarker(body).length,
          );
          content = RichTextHelper.stripPrefix(content, plainPrefix);
        }
        return (
          content: ProcessedContent(content: content, tags: tags),
          type: type,
        );
      case EntryType.note:
        return (
          content: ProcessedContent(
            content: stripTitleAndTags(body, tags, title),
            tags: tags,
          ),
          type: type,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Save orchestration
  // ---------------------------------------------------------------------------

  /// Full save orchestration — mutates only [isSaving] and [error].
  /// Returns `true` when the entry was saved, `false` when there was nothing
  /// to save (both content and title empty). Throws on save failure.
  Future<bool> save() async {
    // Guard: early return if both content and title are empty
    final currentContent = state.content;
    final currentTitle = state.title;
    if (currentContent.isEmpty && currentTitle.isEmpty) return false;

    // Convert Delta JSON → plain text
    final rawPlainText = RichTextHelper.documentToPlainText(
      RichTextHelper.getDocument(currentContent),
    ).trim();

    // Extract tags and split title
    final extracted = extractTags(rawPlainText);
    final text = extracted.clean;
    final contentTags = extracted.tags;

    final parsed = splitTitle(text);
    final parsedTitle = parsed.title;
    final body = parsed.rest;

    // Merge manual + extracted tags (no duplicates)
    final manualTags = state.tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final finalTags = {...manualTags, ...contentTags}.toList();

    // Title: manual overrides parsed
    final finalTitle = currentTitle.isNotEmpty ? currentTitle : parsedTitle;

    // Format content per type (type may change, e.g. credential → note)
    final result = processContentForType(
      state.effectiveType,
      body,
      finalTitle,
      finalTags,
    );

    state = state.copyWith(isSaving: true, error: null);

    try {
      await _createEntry(
        title: finalTitle,
        content: result.content.content,
        type: result.type,
        secret: result.content.secret,
        requiresAuth: result.content.requiresAuth,
        metadata: result.content.metadata,
        tags: result.content.tags,
      );
      _draftNotifier.clear();
      _ref.invalidate(entryListProvider);
      _ref.invalidate(tagSettingsListProvider);
      _ref.invalidate(tagSettingsMapProvider);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle helpers
  // ---------------------------------------------------------------------------

  /// Resets all fields to default (empty) values.
  void reset() {
    state = const CreateEntryState(
      title: '',
      content: '',
      tags: '',
    );
  }

  /// Loads draft content into state.
  void loadDraft(EntryDraft draft) {
    state = state.copyWith(
      title: draft.title,
      content: draft.content,
      tags: draft.tags,
      manualType: draft.manualType,
    );
  }

  /// Sets manual type override.
  void setManualType(EntryType? type) {
    state = state.copyWith(manualType: type);
  }

  /// Updates the manual title field.
  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  /// Updates the manual tags field.
  void setTags(String tags) {
    state = state.copyWith(tags: tags);
  }
}
