import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/usecases/resolve_conflict.dart';
import 'package:taul/infrastructure/database/app_database.dart'
    hide Conflict, Entry;
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/sync/sync_repository_impl.dart';

void main() {
  late AppDatabase database;
  late EntryDao entryDao;
  late ConflictDao conflictDao;
  late SyncRepositoryImpl syncRepository;
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

  setUp(() {
    database = AppDatabase.forTesting();
    entryDao = EntryDao(database);
    conflictDao = ConflictDao(database);
    syncRepository = SyncRepositoryImpl(
      database: database,
      entryDao: entryDao,
      conflictDao: conflictDao,
    );
    useCase = ResolveConflict(syncRepository: syncRepository);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Conflict> seedConflict({
    required Entry local,
    required Entry remote,
  }) async {
    await entryDao.insert(local);
    return conflictDao.insert(
      Conflict(
        id: 0,
        entryId: local.id,
        localVersion: local,
        remoteVersion: remote,
        peerDeviceId: 'peer-device-12345678',
        createdAt: now,
      ),
    );
  }

  group('ResolveConflict (integration)', () {
    test('should_keep_local_leaving_entries_row_unchanged', () async {
      final conflict = await seedConflict(
        local: localVersion,
        remote: remoteVersion,
      );

      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.keepLocal,
      );

      final stored = await entryDao.get(localVersion.id);
      expect(stored, isNotNull);
      expect(stored!.title, 'Local Title');
      expect(stored.version, localVersion.version);

      final resolutions = await conflictDao.getByEntryId(localVersion.id);
      expect(resolutions, hasLength(1));
      expect(resolutions.single.resolution, ConflictResolution.keepLocal);
      expect(resolutions.single.resolvedAt, isNotNull);
    });

    test(
      'should_write_remote_version_and_bump_updated_at_on_keep_remote',
      () async {
        final conflict = await seedConflict(
          local: localVersion,
          remote: remoteVersion,
        );
        final before = DateTime.now();

        await useCase.call(
          conflict: conflict,
          resolution: ConflictResolution.keepRemote,
        );

        final stored = await entryDao.get(localVersion.id);
        expect(stored, isNotNull);
        expect(stored!.title, 'Remote Title');
        expect(stored.content, 'remote content');
        expect(stored.version, remoteVersion.version + 1);
        expect(stored.updatedAt.isAfter(remoteVersion.updatedAt), isTrue);
        expect(
          stored.updatedAt.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse,
        );

        final resolutions = await conflictDao.getByEntryId(localVersion.id);
        expect(resolutions, hasLength(1));
        expect(resolutions.single.resolution, ConflictResolution.keepRemote);
        expect(resolutions.single.resolvedAt, isNotNull);
      },
    );

    test('should_insert_remote_copy_with_new_id_on_keep_both', () async {
      final conflict = await seedConflict(
        local: localVersion,
        remote: remoteVersion,
      );

      await useCase.call(
        conflict: conflict,
        resolution: ConflictResolution.keepBoth,
      );

      final all = await entryDao.list(includeDeleted: true);

      final originals = all.where((e) => e.id == localVersion.id).toList();
      expect(originals, hasLength(1));
      expect(originals.single.title, 'Local Title');

      final copies = all.where((e) => e.id != localVersion.id).toList();
      expect(copies, hasLength(1));
      expect(copies.single.title, 'Remote Title');
      expect(copies.single.id, isNot(remoteVersion.id));
      expect(copies.single.version, 1);

      final resolutions = await conflictDao.getByEntryId(localVersion.id);
      expect(resolutions, hasLength(1));
      expect(resolutions.single.resolution, ConflictResolution.keepBoth);
      expect(resolutions.single.resolvedAt, isNotNull);
    });
  });
}
