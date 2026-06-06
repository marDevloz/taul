import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';

/// Full entry creation sheet with title, rich text editor, tags, and type.
///
/// Ported parsing logic from [QuickAddSheet]: auto-detect type from content
/// (regex `\w:` for glossary, `*` for credential, `!` for idea), extract
/// `Title# ` for auto-title, extract `-#tag` for auto-tags, and parse
/// credentials with [CredentialParser] at save time.
class CreateEntrySheet extends ConsumerStatefulWidget {
  final Future<void> Function()? onCredentialRequested;

  const CreateEntrySheet({super.key, this.onCredentialRequested});

  @override
  ConsumerState<CreateEntrySheet> createState() => _CreateEntrySheetState();
}

class _CreateEntrySheetState extends ConsumerState<CreateEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  var _richContent = '';
  EntryType? _detectedType;
  EntryType? _manualType;
  var _isSaving = false;
  var _didSaveSuccessfully = false;
  late final EntryDraftNotifier _draftNotifier;

  EntryType get _effectiveType => _manualType ?? _detectedType ?? EntryType.note;
  bool get _isManual => _manualType != null;

  @override
  void initState() {
    super.initState();
    _draftNotifier = ref.read(entryDraftProvider.notifier);
    final draft = ref.read(entryDraftProvider);
    if (draft != null) {
      _titleCtrl.text = draft.title;
      _tagsCtrl.text = draft.tags;
      _richContent = draft.content;
      _manualType = draft.manualType;
      if (draft.content.isNotEmpty) {
        _detectTypeFromContent(draft.content);
      }
    }
  }

  @override
  void dispose() {
    if (!_didSaveSuccessfully) {
      final hasContent = _titleCtrl.text.isNotEmpty ||
          _richContent.isNotEmpty ||
          _tagsCtrl.text.isNotEmpty;
      // Notifier may already be disposed during widget tree cleanup;
      // silently drop the draft save — user input loss is acceptable
      // in this edge case (app/route teardown).
      if (hasContent) {
        try {
          _draftNotifier.save(EntryDraft(
            title: _titleCtrl.text,
            content: _richContent,
            tags: _tagsCtrl.text,
            manualType: _manualType,
          ));
        } catch (_) {}
      } else {
        try {
          _draftNotifier.clear();
        } catch (_) {}
      }
    }
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers (ported from QuickAddSheet)
  // ---------------------------------------------------------------------------

  /// Busca "Title# " al inicio del texto y devuelve title + el resto.
  /// El separador es `#` solo — tags ahora usan `-#` así que no hay colisión.
  ({String title, String rest}) _splitTitle(String raw) {
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
  ({String clean, List<String> tags}) _extractTags(String raw) =>
      RichTextHelper.extractTags(raw);

  /// Strips both the `Title# ` prefix and `-#tag` markers from the rich text
  /// content. Used by note and fallback-credential cases where the content
  /// is stored as Delta JSON and the title prefix must not appear in the body.
  String _stripTitleAndTags(List<String> contentTags, String titlePrefix) {
    var stripped = RichTextHelper.stripTagsFromContent(_richContent, contentTags);
    if (titlePrefix.isNotEmpty) {
      stripped = RichTextHelper.stripPrefix(stripped, '$titlePrefix# ');
    }
    return stripped;
  }

  // ---------------------------------------------------------------------------
  // Auto-detección de tipo desde el contenido
  // ---------------------------------------------------------------------------

  void _detectTypeFromContent(String jsonContent) {
    if (jsonContent.isEmpty) return;
    final plainText = RichTextHelper.documentToPlainText(
      RichTextHelper.getDocument(jsonContent),
    ).trim();
    if (plainText.isEmpty) return;

    // Ignorar Title# para la detección de tipo
    final rest = _splitTitle(plainText).rest;

    setState(() {
      if (rest.startsWith('!') && rest.length > 1 && rest[1] != ' ') {
        // ! seguido de NO espacio → idea
        _detectedType = EntryType.idea;
      } else if (RichTextHelper.startsWithTaskMarker(rest)) {
        // [] / [ ] / - [ ] → tarea
        _detectedType = EntryType.task;
      } else if (RegExp(r'\S\*\S').hasMatch(rest)) {
        // * rodeado de NO espacios en ambos lados → credencial
        _detectedType = EntryType.credential;
      } else if (RegExp(r'\w:\S').hasMatch(rest)) {
        // palabra seguida de : sin espacio antes ni después → glosario
        _detectedType = EntryType.glossary;
      } else {
        _detectedType = EntryType.note;
      }
    });
  }

  /// Setea el tipo manualmente desde el PopupMenuButton.
  /// `null` significa "Auto" (usa el detectado).
  void _setType(EntryType? type) {
    setState(() => _manualType = type);
  }

  // ---------------------------------------------------------------------------
  // Save con parsing completo (igual que QuickAddSheet)
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final rawPlainText = RichTextHelper.documentToPlainText(
      RichTextHelper.getDocument(_richContent),
    ).trim();
    final manualTitle = _titleCtrl.text.trim();
    if (rawPlainText.isEmpty && manualTitle.isEmpty) return;

    // Extraer -#tags del contenido
    final extracted = _extractTags(rawPlainText);
    final text = extracted.clean;
    final contentTags = extracted.tags;

    // Extraer Title# del contenido
    final parsed = _splitTitle(text);
    final parsedTitle = parsed.title;
    final body = parsed.rest;

    // Title: manual overridea el extraído del contenido
    final title = manualTitle.isNotEmpty ? manualTitle : parsedTitle;

    // Tags: unir manuales + extraídos (sin duplicados)
    final manualTags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final tags = {...manualTags, ...contentTags}.toList();

    var type = _effectiveType;
    String content;
    Map<String, String> metadata = {};
    String? secret;
    bool requiresAuth = false;

    switch (type) {
      case EntryType.idea:
        // Sacar el ! del inicio
        content = body.startsWith('!') ? body.substring(1).trim() : body;
      case EntryType.glossary:
        content = RichTextHelper.formatForGlossary(body);
      case EntryType.credential:
        final parsedCred = CredentialParser.parse(rawPlainText);
        if (parsedCred != null) {
          content = parsedCred.username.isNotEmpty
              ? 'Usuario: ${parsedCred.username}'
              : parsedCred.service;
          metadata = {
            if (parsedCred.username.isNotEmpty) 'username': parsedCred.username,
            if (parsedCred.url.isNotEmpty) 'url': parsedCred.url,
          };
          secret = parsedCred.password;
          requiresAuth = true;
          tags.addAll(parsedCred.tags.where((t) => !tags.contains(t)));
        } else {
          // No se pudo parsear como credencial — guardar como nota
          type = EntryType.note;
          content = _stripTitleAndTags(contentTags, parsedTitle);
        }
      case EntryType.task:
        content = RichTextHelper.stripTagsFromContent(_richContent, contentTags);
        // Si el contenido plano empieza con [] lo limpiamos también
        if (RichTextHelper.startsWithTaskMarker(body)) {
          final plainContent = RichTextHelper.stripTaskMarker(body);
          // Regenerar rich content sin el marker
          content = jsonEncode([
            {'insert': '$plainContent\n'},
          ]);
        }
      case EntryType.note:
        content = _stripTitleAndTags(contentTags, parsedTitle);
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(createEntryProvider).call(
            title: title,
            content: content,
            type: type,
            secret: secret,
            requiresAuth: requiresAuth,
            metadata: metadata,
            tags: tags,
          );
      _didSaveSuccessfully = true;
      _draftNotifier.clear();
      ref.invalidate(entryListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header con selector de tipo
          Row(
            children: [
              const Icon(Icons.add, size: 20),
              const SizedBox(width: 8),
              Text('Nueva entrada', style: theme.textTheme.titleMedium),
              const Spacer(),
              PopupMenuButton<EntryType?>(
                onSelected: _setType,
                tooltip: 'Cambiar tipo',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isManual
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(_effectiveType), size: 14),
                      const SizedBox(width: 4),
                      Text(_labelForType(_effectiveType), style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
                itemBuilder: (_) => [
                  ...EntryType.values
                      .where((t) => t != EntryType.credential)
                      .map(
                        (t) => PopupMenuItem(
                          value: t,
                          child: ListTile(
                            dense: true,
                            leading: Icon(_iconForType(t), size: 18),
                            title: Text(_labelForType(t), style: const TextStyle(fontSize: 13)),
                            trailing: _effectiveType == t && _isManual
                                ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                                : null,
                          ),
                        ),
                      ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: null,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.sync, size: 18),
                      title: const Text('Auto', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('detectar del contenido', style: TextStyle(fontSize: 11)),
                      trailing: !_isManual
                          ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Título
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'o escribí Titulo# en el contenido',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Contenido rich text
          const Text('Contenido', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          RichTextEditor(
            initialContent: _richContent,
            onChanged: (v) => setState(() {
              _richContent = v;
              _detectTypeFromContent(v);
            }),
          ),
          const SizedBox(height: 12),

          // Tags
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'o usá -#tag en el contenido',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Botones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de UI
  // ---------------------------------------------------------------------------

  IconData _iconForType(EntryType type) {
    return switch (type) {
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.glossary => Icons.book,
      EntryType.credential => Icons.lock,
      EntryType.task => Icons.checklist,
    };
  }

  String _labelForType(EntryType type) {
    return switch (type) {
      EntryType.note => 'Nota',
      EntryType.idea => 'Idea',
      EntryType.glossary => 'Glosario',
      EntryType.credential => 'Credencial',
      EntryType.task => 'Tarea',
    };
  }
}
