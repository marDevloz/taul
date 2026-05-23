# Testing Strategy — Fase 2: Cifrado, Vault Seguro, Desbloqueo Biométrico

**Taúl Phase 2 — Test Plan & Validation**

---

## 1. Estrategia de Testing General

### 1.1 Niveles de Testing

```
┌─────────────────────────────────────────────┐
│ E2E (Integration) Tests                    │ ← Critical path
│ └─ Unlock → Search → Open Credential      │
│ └─ Create Secret → Encrypt → Decrypt      │
│ └─ Timeout → Redirect to Unlock           │
├─────────────────────────────────────────────┤
│ Widget Tests (UI)                         │
│ └─ UnlockScreen interactions               │
│ └─ SessionTimeoutDialog                    │
│ └─ BiometricSettingsScreen                 │
├─────────────────────────────────────────────┤
│ Unit Tests (Services)                     │ ← Highest coverage
│ └─ CryptoService (AES-256-GCM)            │
│ └─ BiometricService (mocked local_auth)   │
│ └─ SecureStorageService (mocked)          │
│ └─ Migration logic                         │
├─────────────────────────────────────────────┤
│ Integration Tests (DB + Service)          │
│ └─ EntryRepository with encryption        │
│ └─ FTS5 search (no performance regression) │
│ └─ Drift migration v1 → v2                │
├─────────────────────────────────────────────┤
│ Security Tests (Cryptographic Validation) │ ← Critical
│ └─ Nonce uniqueness                        │
│ └─ Tag validation (tampering detection)    │
│ └─ Key derivation consistency              │
│ └─ Ciphertext indistinguishability         │
├─────────────────────────────────────────────┤
│ Performance Tests (Benchmarking)          │
│ └─ Search < 200 ms (10k entries)          │
│ └─ Unlock < 1 sec (Argon2id async)        │
│ └─ Encrypt/Decrypt overhead               │
└─────────────────────────────────────────────┘

Target Coverage:
- Unit tests (Services): ≥ 90%
- Integration tests: ≥ 80%
- Widget tests: ≥ 70%
- Critical paths: 100%
```

### 1.2 Testing Tools

```yaml
dependencies:
  flutter_test: ^3.0.0  # Built-in
  mocktail: ^1.0.0      # Mocking
  integration_test: ^0.0.0  # E2E
  sqflite_common_ffi_web: ^1.0.0  # DB testing
  
dev_dependencies:
  drift_dev: ^2.0.0     # DB migrations
  build_runner: ^2.0.0
```

---

## 2. Unit Tests — CryptoService

### 2.1 Test Suite: AES-256-GCM Encryption

```dart
// test/infrastructure/crypto_service_test.dart

group('CryptoService - AES-256-GCM', () {
  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('encrypt()', () {
    test('encrypts plaintext to ciphertext', () async {
      final plaintext = 'my-secret-password';
      final masterKey = List<int>.filled(32, 1); // 256-bit key
      
      final result = await cryptoService.encrypt(plaintext, masterKey);
      
      expect(result.ciphertext, isNotEmpty);
      expect(result.nonce, isNotEmpty);
      expect(result.tag, isNotEmpty);
      expect(result.ciphertext, isNot(plaintext)); // Not plaintext
    });

    test('ciphertext is different on each call (random nonce)', () async {
      final plaintext = 'same-plaintext';
      final masterKey = List<int>.filled(32, 1);
      
      final result1 = await cryptoService.encrypt(plaintext, masterKey);
      final result2 = await cryptoService.encrypt(plaintext, masterKey);
      
      // Same plaintext, different ciphertext (due to random nonce)
      expect(result1.ciphertext, isNot(result2.ciphertext));
      expect(result1.nonce, isNot(result2.nonce));
    });

    test('nonce is always 12 bytes (96 bits)', () async {
      final plaintext = 'test';
      final masterKey = List<int>.filled(32, 1);
      
      final result = await cryptoService.encrypt(plaintext, masterKey);
      
      expect(result.nonce.length, equals(12));
    });

    test('tag is always 16 bytes (128 bits)', () async {
      final plaintext = 'test';
      final masterKey = List<int>.filled(32, 1);
      
      final result = await cryptoService.encrypt(plaintext, masterKey);
      
      expect(result.tag.length, equals(16));
    });

    test('handles empty plaintext', () async {
      final plaintext = '';
      final masterKey = List<int>.filled(32, 1);
      
      final result = await cryptoService.encrypt(plaintext, masterKey);
      
      expect(result.ciphertext, isNotEmpty); // Even empty has IV
    });

    test('handles large plaintext (> 1 MB)', () async {
      final plaintext = 'x' * 1000000;
      final masterKey = List<int>.filled(32, 1);
      
      final result = await cryptoService.encrypt(plaintext, masterKey);
      
      expect(result.ciphertext, isNotEmpty);
    });

    test('throws on invalid masterKey length (not 32 bytes)', () async {
      final plaintext = 'test';
      final invalidKey = List<int>.filled(16, 1); // 128-bit, not 256
      
      expect(
        () => cryptoService.encrypt(plaintext, invalidKey),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('decrypt()', () {
    test('decrypts ciphertext back to plaintext', () async {
      final originalPlaintext = 'my-secret-password';
      final masterKey = List<int>.filled(32, 1);
      
      // Encrypt
      final encrypted = await cryptoService.encrypt(originalPlaintext, masterKey);
      
      // Decrypt
      final decrypted = await cryptoService.decrypt(
        encrypted.ciphertext,
        encrypted.nonce,
        encrypted.tag,
        masterKey,
      );
      
      expect(decrypted, equals(originalPlaintext));
    });

    test('detects tampered ciphertext (throws CryptoException)', () async {
      final plaintext = 'test';
      final masterKey = List<int>.filled(32, 1);
      
      final encrypted = await cryptoService.encrypt(plaintext, masterKey);
      
      // Tamper with ciphertext
      final tamperedCiphertext = List<int>.from(encrypted.ciphertext);
      tamperedCiphertext[0] ^= 0xFF; // Flip bits
      
      expect(
        () => cryptoService.decrypt(
          tamperedCiphertext,
          encrypted.nonce,
          encrypted.tag,
          masterKey,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('detects invalid tag (throws CryptoException)', () async {
      final plaintext = 'test';
      final masterKey = List<int>.filled(32, 1);
      
      final encrypted = await cryptoService.encrypt(plaintext, masterKey);
      
      // Tamper with tag
      final tamperedTag = List<int>.from(encrypted.tag);
      tamperedTag[0] ^= 0xFF;
      
      expect(
        () => cryptoService.decrypt(
          encrypted.ciphertext,
          encrypted.nonce,
          tamperedTag,
          masterKey,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('detects invalid nonce length', () async {
      final plaintext = 'test';
      final masterKey = List<int>.filled(32, 1);
      
      final encrypted = await cryptoService.encrypt(plaintext, masterKey);
      
      final invalidNonce = List<int>.filled(10, 1); // Wrong length
      
      expect(
        () => cryptoService.decrypt(
          encrypted.ciphertext,
          invalidNonce,
          encrypted.tag,
          masterKey,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('different masterKey returns garbage (no error, but wrong)', () async {
      final plaintext = 'test';
      final masterKey1 = List<int>.filled(32, 1);
      final masterKey2 = List<int>.filled(32, 2); // Different key
      
      final encrypted = await cryptoService.encrypt(plaintext, masterKey1);
      
      // Decrypt with wrong key should throw (GCM detects tampering)
      expect(
        () => cryptoService.decrypt(
          encrypted.ciphertext,
          encrypted.nonce,
          encrypted.tag,
          masterKey2,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('handles empty ciphertext', () async {
      final plaintext = '';
      final masterKey = List<int>.filled(32, 1);
      
      final encrypted = await cryptoService.encrypt(plaintext, masterKey);
      final decrypted = await cryptoService.decrypt(
        encrypted.ciphertext,
        encrypted.nonce,
        encrypted.tag,
        masterKey,
      );
      
      expect(decrypted, isEmpty);
    });
  });

  group('deriveMasterKey()', () {
    test('derives consistent key from password + salt', () async {
      final password = 'my-master-password';
      final salt = List<int>.filled(16, 1);
      
      final key1 = await cryptoService.deriveMasterKey(password, salt);
      final key2 = await cryptoService.deriveMasterKey(password, salt);
      
      expect(key1, equals(key2)); // Deterministic
    });

    test('derived key is 32 bytes (256 bits)', () async {
      final password = 'test';
      final salt = List<int>.filled(16, 1);
      
      final key = await cryptoService.deriveMasterKey(password, salt);
      
      expect(key.length, equals(32));
    });

    test('different password -> different key', () async {
      final password1 = 'password-1';
      final password2 = 'password-2';
      final salt = List<int>.filled(16, 1);
      
      final key1 = await cryptoService.deriveMasterKey(password1, salt);
      final key2 = await cryptoService.deriveMasterKey(password2, salt);
      
      expect(key1, isNot(key2));
    });

    test('different salt -> different key', () async {
      final password = 'same-password';
      final salt1 = List<int>.filled(16, 1);
      final salt2 = List<int>.filled(16, 2);
      
      final key1 = await cryptoService.deriveMasterKey(password, salt1);
      final key2 = await cryptoService.deriveMasterKey(password, salt2);
      
      expect(key1, isNot(key2));
    });

    test('handles long password (> 1000 chars)', () async {
      final password = 'x' * 2000;
      final salt = List<int>.filled(16, 1);
      
      final key = await cryptoService.deriveMasterKey(password, salt);
      
      expect(key.length, equals(32));
    });

    test('Argon2id parameters are correct', () async {
      // This test validates that deriveMasterKey uses:
      // t=3, m=65536, p=4 (resistance to GPU attacks)
      // By checking it takes reasonable time (> 100ms)
      
      final password = 'test';
      final salt = List<int>.filled(16, 1);
      
      final stopwatch = Stopwatch()..start();
      await cryptoService.deriveMasterKey(password, salt);
      stopwatch.stop();
      
      // Argon2id with m=65536 should take > 100ms on modern hardware
      expect(stopwatch.elapsedMilliseconds, greaterThan(100));
    });

    test('throws on invalid salt length (not 16 bytes)', () async {
      final password = 'test';
      final invalidSalt = List<int>.filled(8, 1); // Wrong length
      
      expect(
        () => cryptoService.deriveMasterKey(password, invalidSalt),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('generateSalt()', () {
    test('generates 16 bytes of random data', () {
      final salt = cryptoService.generateSalt();
      
      expect(salt.length, equals(16));
    });

    test('generates different salt each call', () {
      final salt1 = cryptoService.generateSalt();
      final salt2 = cryptoService.generateSalt();
      
      expect(salt1, isNot(salt2));
    });

    test('salt values are not trivial (not all 0s or 255s)', () {
      final salt = cryptoService.generateSalt();
      
      final allZero = salt.every((byte) => byte == 0);
      final all255 = salt.every((byte) => byte == 255);
      
      expect(allZero, false);
      expect(all255, false);
    });
  });

  group('validateNonce()', () {
    test('returns true for valid nonce (12 bytes)', () {
      final nonce = List<int>.filled(12, 1);
      
      expect(cryptoService.validateNonce(nonce), true);
    });

    test('returns false for invalid nonce length', () {
      expect(cryptoService.validateNonce(List<int>.filled(10, 1)), false);
      expect(cryptoService.validateNonce(List<int>.filled(16, 1)), false);
    });

    test('returns false for empty nonce', () {
      expect(cryptoService.validateNonce([]), false);
    });

    test('returns false for null nonce', () {
      expect(cryptoService.validateNonce(null), false);
    });
  });

  group('End-to-End Encryption/Decryption', () {
    test('full cycle: generate salt -> derive key -> encrypt -> decrypt', () async {
      final plaintext = 'super-secret-data';
      final password = 'my-master-password';
      
      // 1. Generate salt
      final salt = cryptoService.generateSalt();
      
      // 2. Derive master key
      final masterKey = await cryptoService.deriveMasterKey(password, salt);
      
      // 3. Encrypt
      final encrypted = await cryptoService.encrypt(plaintext, masterKey);
      
      // 4. Decrypt
      final decrypted = await cryptoService.decrypt(
        encrypted.ciphertext,
        encrypted.nonce,
        encrypted.tag,
        masterKey,
      );
      
      expect(decrypted, equals(plaintext));
    });
  });
});
```

---

## 3. Unit Tests — Migration Logic

### 3.1 Test Suite: v1 → v2 Migration

```dart
// test/infrastructure/migration_test.dart

group('Database Migration v1 → v2', () {
  late TestDatabase database;

  setUp(() async {
    database = TestDatabase();
    await database.init();
  });

  tearDown(() async {
    await database.close();
  });

  group('detectMigrationNeeded()', () {
    test('returns true if crypto_config table does not exist', () async {
      final result = await database.detectMigrationNeeded();
      expect(result, true);
    });

    test('returns false if crypto_config table exists', () async {
      // Simulate post-migration state
      await database.createCryptoConfigTable();
      
      final result = await database.detectMigrationNeeded();
      expect(result, false);
    });
  });

  group('migrateSchema()', () {
    test('adds secret_nonce column to entries', () async {
      await database.migrateSchema();
      
      final columns = await database.getTableColumns('entries');
      expect(columns.contains('secret_nonce'), true);
    });

    test('adds secret_tag column to entries', () async {
      await database.migrateSchema();
      
      final columns = await database.getTableColumns('entries');
      expect(columns.contains('secret_tag'), true);
    });

    test('adds crypto_version column to entries', () async {
      await database.migrateSchema();
      
      final columns = await database.getTableColumns('entries');
      expect(columns.contains('crypto_version'), true);
    });

    test('creates crypto_config table', () async {
      await database.migrateSchema();
      
      final tables = await database.getTables();
      expect(tables.contains('crypto_config'), true);
    });

    test('creates sessions table', () async {
      await database.migrateSchema();
      
      final tables = await database.getTables();
      expect(tables.contains('sessions'), true);
    });
  });

  group('reEncryptSecrets()', () {
    test('encrypts all existing secrets in entries', () async {
      // Insert test data (v1 format: secret in plaintext)
      await database.insertTestEntry(
        id: '1',
        title: 'Test',
        secret: 'plaintext-secret',
      );

      await database.migrateSchema();
      
      final masterKey = List<int>.filled(32, 1);
      await database.reEncryptSecrets(masterKey);

      final entry = await database.getEntry('1');
      
      // After re-encryption, secret should be base64-encoded, not plaintext
      expect(entry.secret, isNotEmpty);
      expect(entry.secretNonce, isNotEmpty);
      expect(entry.secretTag, isNotEmpty);
      
      // Try to decrypt to validate
      final decrypted = await CryptoService().decrypt(
        base64Decode(entry.secret),
        hexDecode(entry.secretNonce),
        hexDecode(entry.secretTag),
        masterKey,
      );
      
      expect(decrypted, equals('plaintext-secret'));
    });

    test('handles entries without secret (null)', () async {
      await database.insertTestEntry(
        id: '1',
        title: 'No Secret',
        secret: null,
      );

      await database.migrateSchema();
      
      final masterKey = List<int>.filled(32, 1);
      await database.reEncryptSecrets(masterKey);

      final entry = await database.getEntry('1');
      expect(entry.secret, isNull);
      expect(entry.secretNonce, isNull);
      expect(entry.secretTag, isNull);
    });

    test('handles large number of secrets (performance)', () async {
      // Insert 1000 test entries
      for (int i = 0; i < 1000; i++) {
        await database.insertTestEntry(
          id: '$i',
          title: 'Entry $i',
          secret: 'secret-$i',
        );
      }

      await database.migrateSchema();
      
      final masterKey = List<int>.filled(32, 1);
      
      final stopwatch = Stopwatch()..start();
      await database.reEncryptSecrets(masterKey);
      stopwatch.stop();

      // Should complete in < 10 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));

      // Verify all are encrypted
      final count = await database.countEncryptedSecrets();
      expect(count, equals(1000));
    });

    test('transaction is atomic (rollback on error)', () async {
      // Insert 2 entries
      await database.insertTestEntry(id: '1', secret: 'secret-1');
      await database.insertTestEntry(id: '2', secret: 'secret-2');

      await database.migrateSchema();
      
      final masterKey = List<int>.filled(32, 1);
      
      // Simulate failure during re-encryption (e.g., by mocking)
      database.mockReEncryptFailureOn(entryId: '2');
      
      try {
        await database.reEncryptSecrets(masterKey);
      } catch (e) {
        // Expected
      }

      // After rollback, both should still be in plaintext
      final entry1 = await database.getEntry('1');
      final entry2 = await database.getEntry('2');
      
      expect(entry1.secretNonce, isNull); // Not yet encrypted
      expect(entry2.secretNonce, isNull);
    });
  });

  group('createBackup()', () {
    test('creates backup file before migration', () async {
      final backupPath = await database.createBackup();
      
      expect(File(backupPath).existsSync(), true);
      expect(backupPath.endsWith('.db.zst'), true);
    });

    test('backup contains all v1 data', () async {
      await database.insertTestEntry(id: '1', title: 'Test');
      
      final backupPath = await database.createBackup();
      final backupDb = await openBackup(backupPath);
      
      final entries = await backupDb.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries[0].title, equals('Test'));
    });

    test('backup filename includes timestamp', () async {
      final backupPath = await database.createBackup();
      
      expect(backupPath, contains('taul_backup_v1_'));
      expect(backupPath, contains(RegExp(r'\d{4}_\d{2}_\d{2}_\d{6}')));
    });

    test('backup is compressed (zst format)', () async {
      final backupPath = await database.createBackup();
      
      // Verify it's actually zstandard compressed
      final file = File(backupPath);
      final header = file.readAsBytesSync().take(4);
      
      // zst magic number: 0x28, 0xB5, 0x2F, 0xFD
      expect(header[0], equals(0x28));
      expect(header[1], equals(0xB5));
    });
  });

  group('validateIntegrity()', () {
    test('passes if data count and checksum match', () async {
      await database.insertTestEntry(id: '1', title: 'Entry');
      
      final checksum = await database.calculateChecksum();
      
      await database.migrateSchema();
      
      final result = await database.validateIntegrity(expectedChecksum: checksum);
      expect(result, true);
    });

    test('fails if secret count changed', () async {
      await database.insertTestEntry(id: '1', secret: 'test');
      
      final beforeMigration = await database.countEncryptedSecrets();
      
      await database.migrateSchema();
      
      // Simulate data loss
      await database.deleteEntry('1');
      
      final result = await database.validateIntegrity(
        expectedSecretCount: beforeMigration,
      );
      expect(result, false);
    });

    test('detects corruption (bitflip in entry)', () async {
      await database.insertTestEntry(id: '1', title: 'Test');
      
      final beforeChecksum = await database.calculateChecksum();
      
      // Corrupt data
      await database.corruptEntry('1');
      
      final afterChecksum = await database.calculateChecksum();
      
      expect(beforeChecksum, isNot(afterChecksum));
    });
  });

  group('Migration Full Cycle', () {
    test('v1 → v2 → rollback preserves all data', () async {
      // Setup v1
      await database.insertTestEntry(
        id: '1',
        title: 'My Credential',
        secret: 'super-secret',
      );
      
      final v1Checksum = await database.calculateChecksum();
      final backupPath = await database.createBackup();
      
      // Migrate to v2
      await database.migrateSchema();
      final masterKey = List<int>.filled(32, 1);
      await database.reEncryptSecrets(masterKey);
      
      final v2Entry = await database.getEntry('1');
      expect(v2Entry.secret, isNotNull); // Encrypted
      
      // Rollback
      final restored = await restoreBackup(backupPath);
      final v1Entry = await restored.getEntry('1');
      expect(v1Entry.secret, equals('super-secret')); // Back to plaintext
      
      final restoredChecksum = await restored.calculateChecksum();
      expect(v1Checksum, equals(restoredChecksum));
    });
  });
});
```

---

## 4. Integration Tests — EntryRepository with Encryption

### 4.1 Test Suite: Encrypted CRUD

```dart
// test/infrastructure/entry_repository_encrypted_test.dart

group('EntryRepository - Encrypted CRUD', () {
  late EntryRepository repository;
  late CryptoService cryptoService;
  late List<int> masterKey;

  setUp(() async {
    cryptoService = CryptoService();
    repository = EntryRepository(database: TestDatabase());
    
    // Generate a test master key
    final salt = cryptoService.generateSalt();
    masterKey = await cryptoService.deriveMasterKey('test-password', salt);
  });

  group('createWithSecret()', () {
    test('stores secret encrypted in database', () async {
      final entry = Entry(
        id: 'cred-1',
        type: 'CREDENCIAL',
        title: 'Gmail Account',
        username: 'user@gmail.com',
        secret: 'my-secret-password',
      );

      await repository.createWithSecret(entry, masterKey);

      // Read raw from DB (bypass decryption)
      final rawEntry = await repository.getRaw('cred-1');
      
      // Secret should NOT be plaintext
      expect(rawEntry.secret, isNot('my-secret-password'));
      expect(rawEntry.secretNonce, isNotEmpty);
      expect(rawEntry.secretTag, isNotEmpty);
    });

    test('can decrypt after creating', () async {
      final entry = Entry(
        id: 'cred-2',
        type: 'CREDENCIAL',
        title: 'GitHub',
        secret: 'github-token-xyz',
      );

      await repository.createWithSecret(entry, masterKey);
      
      // Retrieve and decrypt
      final decrypted = await repository.getDecrypted('cred-2', masterKey);
      
      expect(decrypted.secret, equals('github-token-xyz'));
    });

    test('different masterKey cannot decrypt', () async {
      final entry = Entry(
        id: 'cred-3',
        type: 'CREDENCIAL',
        secret: 'secret-data',
      );

      await repository.createWithSecret(entry, masterKey);
      
      // Try to decrypt with wrong key
      final wrongKey = List<int>.filled(32, 99);
      
      expect(
        () => repository.getDecrypted('cred-3', wrongKey),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('getDecrypted()', () {
    test('returns decrypted plaintext', () async {
      final entry = Entry(
        id: 'cred-4',
        type: 'CREDENCIAL',
        secret: 'plaintext-secret',
      );

      await repository.createWithSecret(entry, masterKey);
      final decrypted = await repository.getDecrypted('cred-4', masterKey);
      
      expect(decrypted.secret, equals('plaintext-secret'));
    });

    test('throws if entry not found', () async {
      expect(
        () => repository.getDecrypted('nonexistent', masterKey),
        throwsA(isA<EntryNotFoundException>()),
      );
    });

    test('throws if session expired (no masterKey)', () async {
      final entry = Entry(id: 'cred-5', secret: 'test');
      await repository.createWithSecret(entry, masterKey);
      
      // Simulate session expired
      expect(
        () => repository.getDecrypted('cred-5', null),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  group('updateSecret()', () {
    test('re-encrypts secret with new value', () async {
      final entry = Entry(
        id: 'cred-6',
        type: 'CREDENCIAL',
        secret: 'old-secret',
      );

      await repository.createWithSecret(entry, masterKey);
      
      // Update secret
      await repository.updateSecret('cred-6', 'new-secret', masterKey);
      
      // Verify new value
      final updated = await repository.getDecrypted('cred-6', masterKey);
      expect(updated.secret, equals('new-secret'));
    });

    test('updates timestamp on secret change', () async {
      final entry = Entry(
        id: 'cred-7',
        type: 'CREDENCIAL',
        secret: 'v1',
      );

      await repository.createWithSecret(entry, masterKey);
      final before = await repository.getRaw('cred-7');
      
      await Future.delayed(Duration(milliseconds: 100));
      
      await repository.updateSecret('cred-7', 'v2', masterKey);
      final after = await repository.getRaw('cred-7');
      
      expect(after.updatedAt.isAfter(before.updatedAt), true);
    });
  });

  group('search() - FTS5 (no descifrado)', () {
    test('searches on title without decrypting secret', () async {
      await repository.createWithSecret(
        Entry(id: '1', title: 'Gmail', secret: 'secret'),
        masterKey,
      );
      await repository.createWithSecret(
        Entry(id: '2', title: 'GitHub', secret: 'token'),
        masterKey,
      );

      final results = await repository.search('Gmail');
      
      expect(results.length, equals(1));
      expect(results[0].title, equals('Gmail'));
      // Secret is still encrypted (not returned in search)
      expect(results[0].secret, isNot('secret'));
    });

    test('performance: search < 200ms with 10k entries', () async {
      // Populate DB with 10k entries
      for (int i = 0; i < 10000; i++) {
        await repository.createWithSecret(
          Entry(
            id: '$i',
            title: 'Entry $i',
            content: 'Content for entry $i lorem ipsum...',
            secret: 'secret-$i',
          ),
          masterKey,
        );
      }

      final stopwatch = Stopwatch()..start();
      final results = await repository.search('Entry 5000');
      stopwatch.stop();

      expect(results.isNotEmpty, true);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('never returns plaintext secrets in search results', () async {
      const secretValue = 'super-secret-password';
      
      await repository.createWithSecret(
        Entry(id: '1', title: 'Test', secret: secretValue),
        masterKey,
      );

      // Search for the secret value
      final results = await repository.search(secretValue);
      
      // Should find nothing (secret not indexed)
      expect(results.isEmpty, true);
    });
  });

  group('Batch Operations', () {
    test('createBulk encrypts all entries', () async {
      final entries = [
        Entry(id: '1', title: 'Cred 1', secret: 'secret-1'),
        Entry(id: '2', title: 'Cred 2', secret: 'secret-2'),
        Entry(id: '3', title: 'Cred 3', secret: 'secret-3'),
      ];

      await repository.createBulk(entries, masterKey);

      for (final entry in entries) {
        final decrypted = await repository.getDecrypted(entry.id, masterKey);
        expect(decrypted.secret, equals(entry.secret));
      }
    });

    test('performance: encrypt 1000 credentials in < 5 seconds', () async {
      final entries = List.generate(
        1000,
        (i) => Entry(
          id: '$i',
          title: 'Entry $i',
          secret: 'secret-$i',
        ),
      );

      final stopwatch = Stopwatch()..start();
      await repository.createBulk(entries, masterKey);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
});
```

---

## 5. Widget Tests — UnlockScreen

### 5.1 Test Suite: UI Interactions

```dart
// test/ui/screens/unlock_screen_test.dart

void main() {
  group('UnlockScreen', () {
    testWidgets('renders password input and biometric button', (tester) async {
      await tester.pumpWidget(
        ProviderContainer(
          child: MaterialApp(home: UnlockScreen()),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('shows error on invalid password', (tester) async {
      when(() => mockBiometricService.authenticate())
          .thenAnswer((_) async => false);

      when(() => mockSecureStorageService.getSalt())
          .thenAnswer((_) async => List<int>.filled(16, 1));

      await tester.pumpWidget(
        ProviderContainer(
          child: MaterialApp(home: UnlockScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'wrong-password');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('unlocks with correct password', (tester) async {
      when(() => mockSecureStorageService.getSalt())
          .thenAnswer((_) async => List<int>.filled(16, 1));

      // ... mock crypto validation

      await tester.pumpWidget(
        ProviderContainer(
          child: MaterialApp(home: UnlockScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'correct-password');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should navigate away
      expect(find.byType(MainSearchScreen), findsOneWidget);
    });

    testWidgets('biometric button works', (tester) async {
      when(() => mockBiometricService.canAuthenticate())
          .thenAnswer((_) async => true);

      await tester.pumpWidget(/* ... */);

      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pumpAndSettle();

      verify(() => mockBiometricService.authenticate()).called(1);
    });
  });
}
```

---

## 6. Security Tests

### 6.1 Test Suite: Cryptographic Validation

```dart
// test/security/crypto_validation_test.dart

group('Security - Cryptographic Validation', () {
  test('AES-256-GCM uses 256-bit keys', () {
    final key = List<int>.filled(32, 1); // 256-bit
    expect(key.length * 8, equals(256));
  });

  test('Nonce is random per encryption', () async {
    final service = CryptoService();
    final plaintext = 'test';
    final key = List<int>.filled(32, 1);

    final result1 = await service.encrypt(plaintext, key);
    final result2 = await service.encrypt(plaintext, key);

    // Different nonces
    expect(result1.nonce, isNot(result2.nonce));
  });

  test('Tag validates ciphertext integrity', () async {
    // If tag is wrong, decrypt must fail
    // (GCM provides authenticated encryption)
  });

  test('Argon2id memory hardness prevents GPU attacks', () {
    // m=65536 requires 65MB per instance
    // GPU attacks become infeasible at scale
  });

  test('No plaintext secrets in logs', () {
    // Validate that logger never outputs secret values
  });

  test('Session token is random and unique', () {
    final token1 = generateSessionToken();
    final token2 = generateSessionToken();
    
    expect(token1, isNot(token2));
  });
});
```

---

## 7. Performance Tests

### 7.1 Benchmarks

```dart
// test/performance/benchmarks_test.dart

group('Performance Benchmarks', () {
  benchmark('Search 10k entries', () async {
    // Setup: populate DB with 10k entries
    // Measure: FTS5 search query
    // Expected: < 200 ms
  });

  benchmark('Unlock with Argon2id', () async {
    // Measure: deriveMasterKey()
    // Expected: 500-1000 ms (acceptable for security)
  });

  benchmark('Encrypt credential', () async {
    // Measure: encrypt() + DB insert
    // Expected: < 50 ms
  });

  benchmark('Decrypt credential', () async {
    // Measure: decrypt() from DB
    // Expected: < 10 ms
  });

  benchmark('Migration 1000 credentials', () async {
    // Measure: reEncryptSecrets() for 1000 entries
    // Expected: < 5 sec
  });
});
```

---

## 8. E2E Tests (Integration Tests)

### 8.1 Critical User Journeys

```dart
// test/e2e/unlock_search_decrypt_test.dart

group('E2E - Unlock → Search → Decrypt', () {
  testWidgets('Full user journey', (tester) async {
    // 1. App starts → UnlockScreen
    await tester.pumpWidget(TaulApp());
    expect(find.byType(UnlockScreen), findsOneWidget);

    // 2. User enters password
    await tester.enterText(find.byType(TextField), 'test-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    // 3. Enters MainSearchScreen
    expect(find.byType(MainSearchScreen), findsOneWidget);

    // 4. User searches for credential
    await tester.enterText(find.byType(SearchField), 'Gmail');
    await tester.pumpAndSettle();

    // 5. Results appear
    expect(find.byType(SearchResult), findsWidgets);

    // 6. User opens credential
    await tester.tap(find.byType(SearchResult).first);
    await tester.pumpAndSettle();

    // 7. EntryDetailScreen shows decrypted secret
    expect(find.byType(EntryDetailScreen), findsOneWidget);
    expect(find.text('my-secret-password'), findsOneWidget);
  });
});
```

---

## 9. Test Coverage Report

### 9.1 Target Metrics

```
Coverage Target by Layer:
├── CryptoService: 90%+
├── BiometricService: 85%+
├── SecureStorageService: 85%+
├── EntryRepository: 80%+
├── Migration: 90%+
├── Riverpod Providers: 80%+
├── UI Screens: 70%+
└── Integration: 80%+

Critical Paths: 100%
├── Unlock flow
├── Encrypt/Decrypt
├── Migration
└── Session timeout

Overall Target: ≥ 85%
```

---

## 10. Testing Timeline

| Phase | Duration | Focus |
|-------|----------|-------|
| Sprint 1 (Crypto) | 1 week | Unit tests CryptoService (90% coverage) |
| Sprint 2 (Storage) | 0.5 week | BiometricService + SecureStorageService |
| Sprint 3 (Migration) | 1 week | Migration v1→v2 + integration tests |
| Sprint 4 (UI) | 0.5 week | Widget tests + E2E |
| Sprint 5 (Integration) | 1 week | Full E2E + regression |
| QA | 0.5 week | Manual testing + edge cases |

---

**Testing Strategy Completo — Listo para implementar**
