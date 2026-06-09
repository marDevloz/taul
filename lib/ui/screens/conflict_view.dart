import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/ui/providers/sync_providers.dart';

class ConflictView extends ConsumerWidget {
  const ConflictView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(pendingConflictsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Conflictos')),
      body: conflictsAsync.when(
        data: (conflicts) => conflicts.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('Sin conflictos pendientes'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: conflicts.length,
                itemBuilder: (_, i) => _ConflictCard(conflict: conflicts[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict});

  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          conflict.localVersion.title.isNotEmpty
              ? conflict.localVersion.title
              : 'Sin título',
        ),
        subtitle: Text(
          'Dispositivo: ${conflict.peerDeviceId.substring(0, 8)}...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ConflictDetail(conflict: conflict),
          ),
        ),
      ),
    );
  }
}

class _ConflictDetail extends ConsumerWidget {
  const _ConflictDetail({required this.conflict});

  final Conflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = conflict.localVersion;
    final remote = conflict.remoteVersion;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de conflicto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DiffSection(
            title: 'Título',
            local: local.title,
            remote: remote.title,
          ),
          const SizedBox(height: 12),
          _DiffSection(
            title: 'Contenido',
            local: local.content,
            remote: remote.content,
          ),
          const SizedBox(height: 12),
          _DiffSection(
            title: 'Etiquetas',
            local: local.tags.join(', '),
            remote: remote.tags.join(', '),
          ),
          const SizedBox(height: 12),
          _DiffSection(
            title: 'Metadatos',
            local: 'Modificado: ${local.updatedAt}',
            remote: 'Modificado: ${remote.updatedAt}',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(resolveConflictProvider)(
                      conflict.id,
                      ConflictResolution.keepLocal,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Mantener local'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(resolveConflictProvider)(
                      conflict.id,
                      ConflictResolution.keepRemote,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Mantener remoto'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () {
                ref.read(resolveConflictProvider)(
                  conflict.id,
                  ConflictResolution.keepBoth,
                );
                Navigator.pop(context);
              },
              child: const Text('Mantener ambos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffSection extends StatefulWidget {
  const _DiffSection({
    required this.title,
    required this.local,
    required this.remote,
  });

  final String title;
  final String local;
  final String remote;

  @override
  State<_DiffSection> createState() => _DiffSectionState();
}

class _DiffSectionState extends State<_DiffSection> {
  static const _maxLen = 5000;
  bool _expanded = false;

  String _truncate(String text) {
    if (text.length <= _maxLen || _expanded) return text;
    return '${text.substring(0, _maxLen)}...';
  }

  @override
  Widget build(BuildContext context) {
    final needsTruncation =
        (widget.local.length > _maxLen || widget.remote.length > _maxLen) &&
            !_expanded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Local:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(_truncate(widget.local)),
            const SizedBox(height: 8),
            Text(
              'Remoto:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(_truncate(widget.remote)),
            if (needsTruncation) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: const Text('Mostrar todo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
