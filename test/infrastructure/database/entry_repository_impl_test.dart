import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAppDatabase db;
  late EntryRepositoryImpl repository;

  setUp(() {
    db = MockAppDatabase();
    repository = EntryRepositoryImpl(db: db);
  });

  group('EntryRepositoryImpl', () {
    test('should_create_entry', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => db.insertEntry(any())).thenAnswer((_) => Future.value(entry));

      final result = await repository.create(entry);
      expect(result.id, 'test-id');
      verify(() => db.insertEntry(entry)).called(1);
    });

    test('should_get_entry_by_id', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => db.getEntry('test-id')).thenAnswer((_) => Future.value(entry));

      final result = await repository.getById('test-id');
      expect(result.id, 'test-id');
    });

    test('should_throw_when_entry_not_found', () async {
      when(() => db.getEntry('missing')).thenAnswer((_) => Future.value(null));

      expect(
        () => repository.getById('missing'),
        throwsA(isA<EntryNotFoundFailure>()),
      );
    });

    test('should_soft_delete_entry', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => db.getEntry('test-id')).thenAnswer((_) => Future.value(entry));
      when(() => db.updateEntry(any())).thenAnswer((invocation) {
        return Future.value(invocation.positionalArguments[0] as Entry);
      });

      await repository.softDelete('test-id');
      verify(() => db.updateEntry(any())).called(1);
    });
  });
}
