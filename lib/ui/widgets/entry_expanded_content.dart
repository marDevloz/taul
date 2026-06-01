import 'package:flutter/material.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/widgets/rich_text_display.dart';

class EntryExpandedContent extends StatelessWidget {
  final Entry entry;
  final bool isSecure;
  final VoidCallback? onUnlock;

  const EntryExpandedContent({
    super.key,
    required this.entry,
    this.isSecure = false,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    if (isSecure) {
      return _buildLockedContent(context);
    }
    return _buildContent(context);
  }

  Widget _buildLockedContent(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.lock, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contenido bloqueado',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onUnlock,
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (entry.type == EntryType.credential) {
      return _buildCredentialContent(context);
    }
    return _buildTextContent(context);
  }

  Widget _buildCredentialContent(BuildContext context) {
    final theme = Theme.of(context);
    final username = entry.metadata['username'] ?? '';
    final masked = CredentialParser.maskUsername(username);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            masked,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: RichTextDisplay(content: entry.content),
    );
  }
}
