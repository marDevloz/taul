import 'package:flutter/material.dart';
import 'package:taul/ui/widgets/entry_form_sheet.dart';

/// Thin wrapper that shows the unified [EntryFormSheet] in create mode.
class CreateEntrySheet extends StatelessWidget {
  final Future<void> Function()? onCredentialRequested;

  const CreateEntrySheet({super.key, this.onCredentialRequested});

  @override
  Widget build(BuildContext context) {
    return EntryFormSheet(onCredentialRequested: onCredentialRequested);
  }
}
