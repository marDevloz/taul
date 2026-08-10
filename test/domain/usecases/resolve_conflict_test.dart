import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/domain/usecases/resolve_conflict.dart';

class MockSyncRepository extends Mock implements ISyncRepository {}

void main() {
  late MockSyncRepository syncRepository;
  late ResolveConflict useCase;

  final now = DateTime(2026, 1, 1, 12);
  final localVersion = Entry(
    id: 'entry-1',
    type: EntryType.note,
    title: 'Local Title',
    content: 'local content',
    createdAt: now,
    updatedAt: now,
    version: 2,
  );
  final remoteVersion = Entry(
    id: 'entry-1',
    type: EntryType.note,
    title: 'Remote Title',
    content: 'remote content',
    createdAt: now,
    updatedAt: now.add(const Duration(minutes: 1)),
    version: 3,
  );
  final conflict = Conflict(
    id: 42,
    entryId: 'entry-1',
    localVersion: localVersion,
    remoteVersion: remoteVersion,
    peerDeviceId: 'peer-device-12345678',
    createdAt: now,
  );

  setUpAll(() {
    registerFallbackValue(
      Entry(
        id: 'fallback',
        type: EntryType.note,
        title: 'fallback',
        content: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    registerFallbackValue(ConflictResolution.keepLocal);
    registerFallbackValue(conflict);
  });

  setUp(() {
    syncRepository = MockSyncRepository();
    useCase = ResolveConflict(syncRepository: syncRepository);
    when(
      () => syncRepository.applyConflictResolution(
        conflict: any(named: 'conflict'),
        resolution: any(named: 'resolution'),
        entryToUpdate: any(named: 'entryToUpdate'),
        entryToInsert: any(named: 'entryToInsert'),
      ),
    ).thenAnswer((_) async {});
  });

  group('ResolveConflict', () {
    test('should_call_apply_without_entry_writes_when_keep_local', () async {
      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.keepLocal,
      );

      verify(
        () => syncRepository.applyConflictResolution(
          conflict: conflict,
          resolution: ConflictResolution.keepLocal,
          entryToUpdate: null,
          entryToInsert: null,
        ),
      ).called(1);
    });

    test('should_write_remote_version_when_keep_remote', () async {
      final before = DateTime.now();

      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.keepRemote,
      );

      final captured = verify(
        () => syncRepository.applyConflictResolution(
          conflict: any(named: 'conflict'),
          resolution: any(named: 'resolution'),
          entryToUpdate: captureAny(named: 'entryToUpdate'),
          entryToInsert: any(named: 'entryToInsert'),
        ),
      ).captured;
      final winner = captured.single as Entry;
      expect(winner.id, remoteVersion.id);
      expect(winner.title, 'Remote Title');
      expect(winner.version, remoteVersion.version + 1);
      expect(winner.updatedAt.isBefore(before), isFalse);
    });

    test('should_insert_remote_copy_when_keep_both', () async {
      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.keepBoth,
      );

      final captured = verify(
        () => syncRepository.applyConflictResolution(
          conflict: any(named: 'conflict'),
          resolution: any(named: 'resolution'),
          entryToUpdate: any(named: 'entryToUpdate'),
          entryToInsert: captureAny(named: 'entryToInsert'),
        ),
      ).captured;
      final copy = captured.single as Entry;
      expect(copy.id, isNot(remoteVersion.id));
      expect(copy.id, isNot(localVersion.id));
      expect(copy.title, 'Remote Title');
      expect(copy.version, 1);
      expect(copy.deletedAt, isNull);
    });

    test('should_never_apply_when_pending', () async {
      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.pending,
      );

      verifyNever(
        () => syncRepository.applyConflictResolution(
          conflict: any(named: 'conflict'),
          resolution: any(named: 'resolution'),
          entryToUpdate: any(named: 'entryToUpdate'),
          entryToInsert: any(named: 'entryToInsert'),
        ),
      );
    });
  });
}
