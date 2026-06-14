import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/sync_providers.dart';
import 'package:taul/ui/screens/sync_connect_sheet.dart';

class SyncView extends ConsumerWidget {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceIdAsync = ref.watch(deviceIdProvider);
    final syncState = ref.watch(syncStateProvider);
    final lockStatus = ref.watch(appLockProvider);
    final conflictCount = ref.watch(conflictCountProvider);
    final isLocked = lockStatus != AppLockStatus.unlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: isLocked
          ? const _LockedBody()
          : _SyncBody(
              deviceIdAsync: deviceIdAsync,
              syncState: syncState,
              conflictCount: conflictCount,
            ),
    );
  }
}

class _LockedBody extends StatelessWidget {
  const _LockedBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Desbloqueá el vault para sincronizar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _SyncBody extends ConsumerWidget {
  const _SyncBody({
    required this.deviceIdAsync,
    required this.syncState,
    required this.conflictCount,
  });

  final AsyncValue<String> deviceIdAsync;
  final SyncState syncState;
  final AsyncValue<int> conflictCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        deviceIdAsync.when(
          data: (id) => Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('ID del dispositivo'),
              subtitle: Text(
                id.length > 12 ? '${id.substring(0, 12)}...' : id,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Cargando ID...'),
            ),
          ),
          error: (e, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error),
              title: Text('Error: $e'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatusCard(syncState: syncState),
        const SizedBox(height: 16),
        if (syncState.canStart) ...[
          _ConnectCard(syncState: syncState),
          const SizedBox(height: 16),
        ],
        if (syncState == SyncState.complete) ...[
          const _SyncResultCard(),
          const SizedBox(height: 16),
        ],
        _QrSection(syncState: syncState),
        const SizedBox(height: 16),
        conflictCount.when(
          data: (count) => count > 0
              ? Card(
                  child: ListTile(
                    leading: Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.warning_amber),
                    ),
                    title: Text('$count conflictos pendientes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/sync/conflicts'),
                  ),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        _SyncActionButton(syncState: syncState),
      ],
    );
  }
}

class _QrSection extends ConsumerStatefulWidget {
  const _QrSection({required this.syncState});

  final SyncState syncState;

  @override
  ConsumerState<_QrSection> createState() => _QrSectionState();
}

class _QrSectionState extends ConsumerState<_QrSection> {
  String? _qrData;

  @override
  void didUpdateWidget(_QrSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncState == SyncState.pairing && _qrData == null) {
      _loadQrData();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.syncState == SyncState.pairing) {
      _loadQrData();
    }
  }

  Future<void> _loadQrData() async {
    try {
      final port = ref.read(syncPortProvider);
      final pairingService = ref.read(syncPairingServiceProvider);
      final pairingCode = ref.read(syncPairingCodeProvider);
      if (port == null || pairingService == null || pairingCode == null) return;
      final ip = await pairingService.getLocalIpAddress();
      final qrData = 'https://$ip:$port?code=$pairingCode';
      if (mounted) setState(() => _qrData = qrData);
    } catch (_) {
      // IP detection failed — leave QR data null
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairingCode = ref.watch(syncPairingCodeProvider);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: widget.syncState == SyncState.pairing && _qrData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 160,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Código: $pairingCode',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escaneá este código desde el otro dispositivo',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Código QR',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Disponible durante pairing',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (syncState) {
      SyncState.idle => (Icons.check_circle_outline, 'Inactivo', Colors.grey),
      SyncState.connecting => (
          Icons.sync,
          'Conectando...',
          Colors.blue,
        ),
      SyncState.pairing => (
          Icons.handshake,
          'Esperando conexión...',
          Colors.orange,
        ),
      SyncState.syncing => (
          Icons.sync,
          'Sincronizando...',
          Colors.blue,
        ),
      SyncState.complete => (
          Icons.check_circle,
          'Completado',
          Colors.green,
        ),
      SyncState.error => (Icons.error, 'Error', Colors.red),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: const Text('Estado'),
        subtitle: Text(label),
      ),
    );
  }
}

class _SyncActionButton extends ConsumerWidget {
  const _SyncActionButton({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = syncState.isActive;

    return FilledButton.icon(
      onPressed: () {
        if (isActive) {
          ref.read(stopSyncProvider)();
        } else {
          ref.read(startSyncProvider)();
        }
      },
      icon: Icon(isActive ? Icons.stop : Icons.sync),
      label: Text(isActive ? 'Detener' : 'Iniciar sincronización'),
    );
  }
}

/// Card that opens the connect sheet when tapped.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Conectar a dispositivo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SyncConnectSheet(),
          );
        },
      ),
    );
  }
}

/// Card showing the result of the last completed sync.
class _SyncResultCard extends ConsumerWidget {
  const _SyncResultCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(lastSyncResultProvider);
    if (result == null) return const SizedBox.shrink();

    final hasConflicts = result.conflictsCount > 0;
    final label = hasConflicts
        ? '${result.entriesUpserted} entradas sincronizadas, '
            '${result.conflictsCount} conflictos'
        : '${result.entriesUpserted} entradas sincronizadas, sin conflictos';

    return Card(
      child: ListTile(
        leading: Icon(
          hasConflicts ? Icons.warning_amber : Icons.check_circle,
          color: hasConflicts ? Colors.orange : Colors.green,
        ),
        title: Text(label),
        trailing: hasConflicts
            ? FilledButton.tonal(
                onPressed: () => context.push('/sync/conflicts'),
                child: const Text('Resolver conflictos'),
              )
            : null,
      ),
    );
  }
}
