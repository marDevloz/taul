import 'package:flutter/material.dart';
import 'package:taul/ui/widgets/entry_form_sheet.dart';

/// Thin wrapper that shows the unified [EntryFormSheet] in create mode.
class CreateEntrySheet extends StatelessWidget {
  const CreateEntrySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const EntryFormSheet();
  }
}
