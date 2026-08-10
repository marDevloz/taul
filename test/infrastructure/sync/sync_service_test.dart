import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_server.dart';
import 'package:taul/infrastructure/sync/sync_service.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

class MockSyncServer extends Mock implements SyncServer {}
class MockSyncClient extends Mock implements SyncClient {}

void main() {
  late SyncService service;
  late MockSyncServer server;
  late MockSyncClient client;

  setUpAll(() {
    registerFallbackValue(const SyncRequest(deviceId: ''));
  });

  setUp(() {
    server = MockSyncServer();
    client = MockSyncClient();
    when(() => server.stop()).thenAnswer((_) async {});
    service = SyncService(
      server: server,
      client: client,
      deviceId: 'test-device',
      onRequest: (_) async => const SyncResponse(
        deviceId: 'test-device',
        entriesReceived: 0,
        conflictsCount: 0,
      ),
    );
  });

  tearDown(() {
    service.dispose();
  });

  group('state transitions', () {
    test('starts idle', () {
      expect(service.currentState, SyncState.idle);
    });

    test('emits pairing after startServer', () async {
      when(() => server.start()).thenAnswer((_) async => 54321);
      final states = <SyncState>[];
      service.stateStream.listen(states.add);

      await service.startServer();
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(SyncState.pairing));
    });

    test('emits error when server fails', () async {
      when(() => server.start()).thenThrow(Exception('port in use'));
      final states = <SyncState>[];
      service.stateStream.listen(states.add);

      await service.startServer();
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(SyncState.error));
    });

    test('emits complete after successful sync', () async {
      when(() => server.start()).thenAnswer((_) async => 54321);
      when(() => client.sync(
        host: '192.168.1.100',
        port: 54321,
        expectedFingerprint: <int>[],
        pairingCode: '123456',
        request: any(named: 'request'),
      )).thenAnswer((_) async => const SyncResponse(
        deviceId: 'test-device',
        entriesReceived: 5,
        conflictsCount: 0,
      ));

      await service.startServer();
      await Future<void>.delayed(Duration.zero);
      final states = <SyncState>[];
      service.stateStream.listen(states.add);

      await service.performSync(
        host: '192.168.1.100',
        port: 54321,
        fingerprint: [],
        pairingCode: '123456',
        request: const SyncRequest(deviceId: 'test-device'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(SyncState.complete));
    });

    test('emits error then recovers to idle', () {
      when(() => server.start()).thenThrow(Exception('fail'));

      // The 5s recovery timer in SyncService is driven deterministically by
      // FakeAsync instead of sleeping real wall-clock seconds.
      fakeAsync((async) {
        final states = <SyncState>[];
        service.stateStream.listen(states.add);

        service.startServer();
        async.flushMicrotasks();

        expect(states, contains(SyncState.error));
        expect(service.currentState, SyncState.error);

        async.elapse(const Duration(seconds: 6));
        expect(service.currentState, SyncState.idle);
        expect(states, contains(SyncState.idle));
      });
    });
  });

  group('stop', () {
    test('transitions to idle', () async {
      when(() => server.start()).thenAnswer((_) async => 54321);
      when(() => server.stop()).thenAnswer((_) async {});
      await service.startServer();
      await service.stop();
      expect(service.currentState, SyncState.idle);
    });
  });
}
