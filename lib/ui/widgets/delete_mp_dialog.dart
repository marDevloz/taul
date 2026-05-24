import 'package:flutter/material.dart';

/// Confirmation dialog for deleting the master password.
///
/// Shows a warning with the count of protected entries that would become
/// unrecoverable. Returns `true` if the user confirms deletion.
class DeleteMpDialog extends StatelessWidget {
  const DeleteMpDialog({super.key, this.protectedEntryCount = 0});

  final int protectedEntryCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
      title: const Text('Delete Master Password?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will permanently delete your master password configuration '
            'including the password hash, hint, and all backup codes.',
          ),
          const SizedBox(height: 12),
          Text(
            protectedEntryCount > 0
                ? 'There ${_areProtected(protectedEntryCount)} '
                    '${_protectedEntries(protectedEntryCount)} that will become '
                    'UNRECOVERABLE.'
                : 'There are no protected entries. You can set up a new '
                    'master password at any time.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: protectedEntryCount > 0 ? Colors.red : Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Text(
              'This action CANNOT be undone. If you have protected entries, '
              'they will be permanently inaccessible.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  String _areProtected(int count) => count == 1 ? 'is' : 'are';
  String _protectedEntries(int count) =>
      count == 1 ? '1 protected entry' : '$count protected entries';
}
