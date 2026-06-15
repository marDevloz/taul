import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_coordinator.dart';
import 'package:taul/infrastructure/sync/sync_service.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/sync_client_providers.dart';
import 'package:taul/ui/providers/sync_providers.dart';

// Mocks
class MockSyncService extends Mock implements SyncService {}
class MockSyncCoordinator extends Mock implements SyncCoordinator {}
class MockSyncRepository extends Mock implements ISyncRepository {}

void main() {
  late MockSyncService syncService;
  late MockSyncCoordinator coordinator;
  late MockSyncRepository syncRepo;
  final now = DateTime.now();

  setUpAll(() {
    registerFallbackValue(const SyncRequest(deviceId: ''));
    registerFallbackValue(
      SyncResponse(deviceId: '', entriesReceived: 0, conflictsCount: 0),
    );
  });

  setUp(() {
    syncService = MockSyncService();
    coordinator = MockSyncCoordinator();
    syncRepo = MockSyncRepository();

    // Default repo stubs — connectAndSyncProvider calls these via syncRepositoryProvider
    when(() => syncRepo.getModifiedEntries(any())).thenAnswer((_) async => []);
    when(() => syncRepo.getLastSyncAt(any())).thenAnswer((_) async => null);
    when(() => syncRepo.setLastSyncAt(any(), any())).thenAnswer((_) async {});
  });

  group('ConnectParams', () {
    test('should_hold_host_port_fingerprint_pairingCode', () {
      const params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      expect(params.host, '192.168.1.100');
      expect(params.port, 54321);
      expect(params.fingerprint, [1, 2, 3, 4, 5]);
      expect(params.pairingCode, '123456');
    });

    test('should_be_immutable', () {
      const params1 = ConnectParams(
        host: 'host',
        port: 1234,
        fingerprint: [],
        pairingCode: '000000',
      );
      const params2 = ConnectParams(
        host: 'host',
        port: 1234,
        fingerprint: [],
        pairingCode: '000000',
      );

      expect(params1, equals(params2));
    });
  });

  group('TLS trust-on-first-use helpers', () {
    test('should_hex_encode_fingerprint', () {
      final fingerprint = [1, 2, 3, 4, 5, 6, 7, 8];
      final hex = fingerprintToHex(fingerprint);

      expect(hex, '0102030405060708');
    });

    test('should_hex_decode_fingerprint', () {
      const hex = '0102030405060708';
      final bytes = hexToFingerprint(hex);

      expect(bytes, [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('should_store_and_retrieve_trusted_fingerprint', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const host = '192.168.1.100';
      const port = 54321;
      final fingerprint = [1, 2, 3, 4, 5, 6, 7, 8];
      final hex = fingerprintToHex(fingerprint);

      // Store
      await prefs.setString('tls_trust_$host:$port', hex);

      // Retrieve and verify
      final stored = prefs.getString('tls_trust_$host:$port');
      expect(stored, hex);

      // Decode back
      final decoded = hexToFingerprint(stored!);
      expect(decoded, fingerprint);
    });

    test('should_return_null_for_unknown_host', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getString('tls_trust_192.168.1.100:54321');
      expect(stored, isNull);
    });
  });

  group('connectAndSyncProvider', () {
    test('should_call_performSync_and_processSyncResponse', () async {
      // Arrange
      final remoteEntries = [
        Entry(
          id: 'remote-1',
          type: EntryType.note,
          title: 'Remote Entry',
          content: 'Remote content',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final response = SyncResponse(
        deviceId: 'remote-device',
        entriesReceived: 1,
        conflictsCount: 0,
        serverLastSyncAt: now,
        entries: remoteEntries,
      );

      when(() => coordinator.processSyncResponse(any()))
          .thenAnswer((_) async => const ProcessSyncResult(
                entriesUpserted: 1,
                conflictsCount: 0,
              ));
      when(() => syncService.performSync(
            host: any(named: 'host'),
            port: any(named: 'port'),
            fingerprint: any(named: 'fingerprint'),
            pairingCode: any(named: 'pairingCode'),
            request: any(named: 'request'),
          )).thenAnswer((_) async => response);

      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          syncRepositoryProvider.overrideWithValue(syncRepo),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      final result = await container.read(
        connectAndSyncProvider(params).future,
      );

      // Assert
      expect(result.entriesUpserted, 1);
      expect(result.conflictsCount, 0);
      verify(() => coordinator.processSyncResponse(response)).called(1);
      verify(() => syncService.performSync(
            host: '192.168.1.100',
            port: 54321,
            fingerprint: [1, 2, 3, 4, 5],
            pairingCode: '123456',
            request: any(named: 'request'),
          )).called(1);
    });

    test('should_set_state_to_complete_on_success', () async {
      // Arrange
      final response = SyncResponse(
        deviceId: 'remote-device',
        entriesReceived: 0,
        conflictsCount: 0,
        serverLastSyncAt: now,
        entries: [],
      );

      when(() => coordinator.processSyncResponse(any()))
          .thenAnswer((_) async => const ProcessSyncResult(
                entriesUpserted: 0,
                conflictsCount: 0,
              ));
      when(() => syncService.performSync(
            host: any(named: 'host'),
            port: any(named: 'port'),
            fingerprint: any(named: 'fingerprint'),
            pairingCode: any(named: 'pairingCode'),
            request: any(named: 'request'),
          )).thenAnswer((_) async => response);

      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          deviceIdProvider.overrideWith((ref) async => 'local-device'),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
          syncRepositoryProvider.overrideWithValue(syncRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      await container.read(connectAndSyncProvider(params).future);

      // Assert - State should be complete
      final state = container.read(syncStateProvider);
      expect(state, SyncState.complete);
    });

    test('should_set_state_to_error_on_failure', () async {
      // Arrange
      when(() => syncService.performSync(
            host: any(named: 'host'),
            port: any(named: 'port'),
            fingerprint: any(named: 'fingerprint'),
            pairingCode: any(named: 'pairingCode'),
            request: any(named: 'request'),
          )).thenThrow(const PairingCodeRejectedException());

      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          deviceIdProvider.overrideWith((ref) async => 'local-device'),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
          syncRepositoryProvider.overrideWithValue(syncRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      await expectLater(
        container.read(connectAndSyncProvider(params).future),
        throwsA(isA<PairingCodeRejectedException>()),
      );

      // Assert - State should be error
      final state = container.read(syncStateProvider);
      expect(state, SyncState.error);
    });

    test('should_handle_timeout_error', () async {
      // Arrange
      when(() => syncService.performSync(
            host: any(named: 'host'),
            port: any(named: 'port'),
            fingerprint: any(named: 'fingerprint'),
            pairingCode: any(named: 'pairingCode'),
            request: any(named: 'request'),
          )).thenThrow(const SyncInterruptedException());

      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          deviceIdProvider.overrideWith((ref) async => 'local-device'),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
          syncRepositoryProvider.overrideWithValue(syncRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      await expectLater(
        container.read(connectAndSyncProvider(params).future),
        throwsA(isA<SyncInterruptedException>()),
      );

      // Assert - State should be error
      final state = container.read(syncStateProvider);
      expect(state, SyncState.error);
    });

    test('should_store_trusted_fingerprint_on_first_connect', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final response = SyncResponse(
        deviceId: 'remote-device',
        entriesReceived: 0,
        conflictsCount: 0,
        serverLastSyncAt: now,
        entries: [],
      );

      when(() => coordinator.processSyncResponse(any()))
          .thenAnswer((_) async => const ProcessSyncResult(
                entriesUpserted: 0,
                conflictsCount: 0,
              ));
      when(() => syncService.performSync(
            host: any(named: 'host'),
            port: any(named: 'port'),
            fingerprint: any(named: 'fingerprint'),
            pairingCode: any(named: 'pairingCode'),
            request: any(named: 'request'),
          )).thenAnswer((_) async => response);

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          deviceIdProvider.overrideWith((ref) async => 'local-device'),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
          syncRepositoryProvider.overrideWithValue(syncRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [1, 2, 3, 4, 5],
        pairingCode: '123456',
      );

      await container.read(connectAndSyncProvider(params).future);

      // Assert - Fingerprint should be stored in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('tls_trust_192.168.1.100:54321');
      expect(stored, fingerprintToHex([1, 2, 3, 4, 5]));
    });

    test('should_throw_on_trusted_fingerprint_mismatch', () async {
      // Arrange
      final originalFingerprint = [1, 2, 3, 4, 5];
      final mismatchFingerprint = [9, 8, 7, 6, 5];

      SharedPreferences.setMockInitialValues({
        'tls_trust_192.168.1.100:54321': fingerprintToHex(originalFingerprint),
      });

      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          syncServiceProvider.overrideWith((ref) => syncService),
          deviceIdProvider.overrideWith((ref) async => 'local-device'),
          syncStateProvider.overrideWith((ref) => SyncState.idle),
          syncRepositoryProvider.overrideWithValue(syncRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final params = ConnectParams(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: mismatchFingerprint,
        pairingCode: '123456',
      );

      expect(
        () => container.read(connectAndSyncProvider(params).future),
        throwsA(isA<TlsFingerprintMismatchException>()),
      );
    });
  });
}

