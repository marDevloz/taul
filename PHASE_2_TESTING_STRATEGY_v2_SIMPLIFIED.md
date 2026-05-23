# Testing Strategy — Fase 2 (v2): Protección Opcional de Entradas

**Taúl Phase 2 Testing Strategy (Simplified)**

---

## 📋 Resumen Ejecutivo

| Métrica | Target | Detalle |
|--------|--------|---------|
| **Total Tests** | ~40-50 | Unit + Integration + Widget |
| **Coverage Goal** | ≥80% | Overall code coverage |
| **Critical Path** | 100% | Encrypt/decrypt/verify |
| **Effort** | 2-3 horas | Incluido en 20h totales |
| **Automation** | ✅ Full | CI/CD pipeline ready |

---

## 1. Estrategia de Testing

### 1.1 Pirámide de Tests

```
           /\
          /  \              E2E Tests (2-3)
         /    \             - Full user journeys
        /      \
       /________\
      /          \            Integration Tests (8-10)
     /            \           - Encrypt → Store → Decrypt
    /              \          - Setup flow
   /________________\
  /                  \         Unit Tests (30-35)
 /                    \        - Encrypt/decrypt
/______________________\       - Key derivation
                               - Providers
                               - Widget tests
```

### 1.2 Testing Layers

```
Layer 1: Unit Tests (EntryAuthService)
  ✅ Encrypt/decrypt roundtrips
  ✅ Key derivation (Argon2id)
  ✅ Nonce randomness
  ✅ GCM tag verification
  ✅ Edge cases (unicode, large secrets)
  └─ Coverage: 90%+

Layer 2: Provider Tests (Riverpod)
  ✅ masterPasswordProvider state mgmt
  ✅ unlockedEntriesProvider auto-clear
  ✅ entryAuthServiceProvider singleton
  └─ Coverage: 85%+

Layer 3: Integration Tests (DB + Encryption)
  ✅ Create protected entry → save to DB → read back
  ✅ Decrypt entry from DB
  ✅ First-time setup flow
  ✅ Unprotected entries (no change)
  └─ Coverage: 80%+

Layer 4: Widget Tests (UI)
  ✅ EntryDetailView [Reveal] button
  ✅ RevealSecretSheet password input
  ✅ CreateEntryForm protect toggle
  ✅ MasterPasswordSetupDialog validation
  └─ Coverage: 75%+

Layer 5: E2E Tests (Full Flow)
  ✅ User creates protected entry (first time)
  ✅ User views & unlocks protected entry
  ✅ User searches and finds protected entries
  └─ Coverage: Full user journey
```

---

## 2. Unit Tests (EntryAuthService)

### 2.1 Encryption Tests

```dart
// Test Suite: EntryAuthService Encryption
group('EntryAuthService - Encryption', () {
  late EntryAuthService service;

  setUp(() {
    service = EntryAuthService();
  });

  test('encrypt_returns_valid_result', () {
    // Given
    const plaintext = 'MySecretPassword123!';
    final key = Uint8List(32); // zeros (for testing)

    // When
    final result = service.encrypt(plaintext, key);

    // Then
    expect(result.encryptedSecret, isNotEmpty);
    expect(result.nonce, isNotEmpty);
    expect(result.tag, isNotEmpty);
    expect(result.nonce.length, equals(24)); // 12 bytes * 2 (hex)
    expect(result.tag.length, equals(32));  // 16 bytes * 2 (hex)
  });

  test('decrypt_returns_plaintext', () {
    // Given
    const plaintext = 'MySecretPassword123!';
    final key = Uint8List(32);
    final encrypted = service.encrypt(plaintext, key);

    // When
    final decrypted = service.decrypt(
      encrypted.encryptedSecret,
      encrypted.nonce,
      encrypted.tag,
      key,
    );

    // Then
    expect(decrypted, equals(plaintext));
  });

  test('encrypt_decrypt_roundtrip_with_unicode', () {
    // Given
    const plaintext = 'Contraseña123!🔒';
    final key = Uint8List(32);

    // When
    final encrypted = service.encrypt(plaintext, key);
    final decrypted = service.decrypt(
      encrypted.encryptedSecret,
      encrypted.nonce,
      encrypted.tag,
      key,
    );

    // Then
    expect(decrypted, equals(plaintext));
  });

  test('different_nonce_each_encrypt', () {
    // Given
    const plaintext = 'MySecret';
    final key = Uint8List(32);

    // When
    final result1 = service.encrypt(plaintext, key);
    final result2 = service.encrypt(plaintext, key);

    // Then (nonces must be different)
    expect(result1.nonce, isNot(equals(result2.nonce)));
  });

  test('decrypt_wrong_key_throws_or_fails', () {
    // Given
    const plaintext = 'MySecret';
    final correctKey = Uint8List(32);
    final wrongKey = Uint8List(32)..fill(255);
    final encrypted = service.encrypt(plaintext, correctKey);

    // When & Then
    expect(
      () => service.decrypt(
        encrypted.encryptedSecret,
        encrypted.nonce,
        encrypted.tag,
        wrongKey,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('decrypt_tampered_tag_throws', () {
    // Given
    const plaintext = 'MySecret';
    final key = Uint8List(32);
    var encrypted = service.encrypt(plaintext, key);

    // Tamper with tag
    final tamperedTag = encrypted.tag.substring(0, 30) + 'XX';

    // When & Then
    expect(
      () => service.decrypt(
        encrypted.encryptedSecret,
        encrypted.nonce,
        tamperedTag,
        key,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('encrypt_large_secret', () {
    // Given
    final plaintext = 'A' * 100000; // 100KB
    final key = Uint8List(32);

    // When
    final encrypted = service.encrypt(plaintext, key);
    final decrypted = service.decrypt(
      encrypted.encryptedSecret,
      encrypted.nonce,
      encrypted.tag,
      key,
    );

    // Then
    expect(decrypted, equals(plaintext));
    expect(decrypted.length, equals(plaintext.length));
  });

  test('encrypt_empty_secret', () {
    // Given
    const plaintext = '';
    final key = Uint8List(32);

    // When
    final encrypted = service.encrypt(plaintext, key);
    final decrypted = service.decrypt(
      encrypted.encryptedSecret,
      encrypted.nonce,
      encrypted.tag,
      key,
    );

    // Then
    expect(decrypted, equals(plaintext));
  });

  // Performance benchmark
  test('encrypt_performance_under_10ms', () {
    // Given
    const plaintext = 'MySecretPassword123!';
    final key = Uint8List(32);

    // When
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 100; i++) {
      service.encrypt(plaintext, key);
    }
    stopwatch.stop();

    // Then
    final avgTime = stopwatch.elapsedMilliseconds / 100;
    expect(avgTime, lessThan(10)); // Average < 10ms per encryption
  });
});
```

### 2.2 Key Derivation Tests

```dart
group('EntryAuthService - Key Derivation', () {
  late EntryAuthService service;

  setUp(() {
    service = EntryAuthService();
  });

  test('generateSalt_returns_16_bytes', () {
    // When
    final salt = service.generateSalt();

    // Then
    expect(salt, isNotEmpty);
    expect(salt.length, equals(32)); // 16 bytes * 2 (hex encoded)
  });

  test('deriveMasterKey_consistent_with_same_inputs', () async {
    // Given
    const password = 'MyPassword123!';
    final salt = service.generateSalt();

    // When
    final key1 = await service.deriveMasterKey(password, salt);
    final key2 = await service.deriveMasterKey(password, salt);

    // Then
    expect(key1, equals(key2));
  });

  test('deriveMasterKey_returns_32_bytes', () async {
    // Given
    const password = 'MyPassword123!';
    final salt = service.generateSalt();

    // When
    final key = await service.deriveMasterKey(password, salt);

    // Then
    expect(key.length, equals(32)); // 256 bits
  });

  test('deriveMasterKey_different_password_different_key', () async {
    // Given
    const password1 = 'Password1';
    const password2 = 'Password2';
    final salt = service.generateSalt();

    // When
    final key1 = await service.deriveMasterKey(password1, salt);
    final key2 = await service.deriveMasterKey(password2, salt);

    // Then
    expect(key1, isNot(equals(key2)));
  });

  test('deriveMasterKey_different_salt_different_key', () async {
    // Given
    const password = 'MyPassword';
    final salt1 = service.generateSalt();
    final salt2 = service.generateSalt();

    // When
    final key1 = await service.deriveMasterKey(password, salt1);
    final key2 = await service.deriveMasterKey(password, salt2);

    // Then
    expect(key1, isNot(equals(key2)));
  });

  test('deriveMasterKey_performance_under_500ms', () async {
    // Given
    const password = 'MyPassword123!';
    final salt = service.generateSalt();

    // When
    final stopwatch = Stopwatch()..start();
    await service.deriveMasterKey(password, salt);
    stopwatch.stop();

    // Then
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('hashPassword_consistent', () {
    // Given
    const password = 'MyPassword123!';
    final salt = service.generateSalt();

    // When
    final hash1 = service.hashPassword(password, salt);
    final hash2 = service.hashPassword(password, salt);

    // Then
    expect(hash1, equals(hash2));
  });

  test('hashPassword_different_password_different_hash', () {
    // Given
    const password1 = 'Password1';
    const password2 = 'Password2';
    final salt = service.generateSalt();

    // When
    final hash1 = service.hashPassword(password1, salt);
    final hash2 = service.hashPassword(password2, salt);

    // Then
    expect(hash1, isNot(equals(hash2)));
  });
});
```

### 2.3 Security Tests

```dart
group('EntryAuthService - Security', () {
  late EntryAuthService service;

  setUp(() {
    service = EntryAuthService();
  });

  test('nonce_uniqueness_across_100_encryptions', () {
    // Given
    const plaintext = 'MySecret';
    final key = Uint8List(32);
    final nonces = <String>{};

    // When
    for (int i = 0; i < 100; i++) {
      final encrypted = service.encrypt(plaintext, key);
      nonces.add(encrypted.nonce);
    }

    // Then
    expect(nonces.length, equals(100)); // All unique
  });

  test('gcm_tag_prevents_ciphertext_tampering', () {
    // Given
    const plaintext = 'MySecret';
    final key = Uint8List(32);
    var encrypted = service.encrypt(plaintext, key);

    // Tamper with ciphertext
    final originalCipherBytes = hex.decode(encrypted.encryptedSecret);
    final tamperedCipherBytes = originalCipherBytes;
    tamperedCipherBytes[0] ^= 1; // Flip 1 bit
    final tamperedCipher = hex.encode(tamperedCipherBytes);

    // When & Then
    expect(
      () => service.decrypt(
        tamperedCipher,
        encrypted.nonce,
        encrypted.tag,
        key,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('no_plaintext_logged_during_encryption', () {
    // Given
    const plaintext = 'SuperSecretPassword';
    final key = Uint8List(32);

    // When
    final encrypted = service.encrypt(plaintext, key);

    // Then (verify plaintext not in hex representations)
    expect(encrypted.encryptedSecret, isNot(contains(plaintext)));
    expect(encrypted.nonce, isNot(contains(plaintext)));
    expect(encrypted.tag, isNot(contains(plaintext)));
  });
});
```

---

## 3. Riverpod Provider Tests

### 3.1 MasterPasswordProvider Tests

```dart
group('MasterPasswordProvider', () {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  test('initial_state_is_null', () {
    // When
    final state = container.read(masterPasswordProvider);

    // Then
    expect(state, isNull);
  });

  test('setMasterPassword_updates_state', () async {
    // Given
    const password = 'MyPassword123!';
    final notifier = container.read(masterPasswordProvider.notifier);

    // Mock: Need to setup master_password_config in DB
    // (This test assumes DB is mocked)

    // When
    await notifier.setMasterPassword(password);

    // Then
    final state = container.read(masterPasswordProvider);
    expect(state, isNotNull);
    expect(state, isA<Uint8List>());
    expect(state!.length, equals(32));
  });

  test('clearMasterPassword_sets_state_to_null', () async {
    // Given
    const password = 'MyPassword123!';
    final notifier = container.read(masterPasswordProvider.notifier);

    // Setup state
    // (mocked)

    // When
    notifier.clearMasterPassword();

    // Then
    final state = container.read(masterPasswordProvider);
    expect(state, isNull);
  });

  test('isMasterPasswordSet_returns_true_if_state_not_null', () async {
    // Given
    // (state is not null after setMasterPassword)

    // When
    final notifier = container.read(masterPasswordProvider.notifier);
    final isSet = notifier.isMasterPasswordSet();

    // Then
    expect(isSet, isTrue);
  });

  test('isMasterPasswordSet_returns_false_if_state_null', () {
    // When
    final notifier = container.read(masterPasswordProvider.notifier);
    final isSet = notifier.isMasterPasswordSet();

    // Then
    expect(isSet, isFalse);
  });
});
```

### 3.2 UnlockedEntriesProvider Tests

```dart
group('UnlockedEntriesProvider', () {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  test('initial_state_is_empty_set', () {
    // When
    final state = container.read(unlockedEntriesProvider);

    // Then
    expect(state, isEmpty);
  });

  test('markUnlocked_adds_entry_id', () {
    // Given
    const entryId = 'entry-123';
    final notifier = container.read(unlockedEntriesProvider.notifier);

    // When
    notifier.markUnlocked(entryId);

    // Then
    final state = container.read(unlockedEntriesProvider);
    expect(state, contains(entryId));
  });

  test('markUnlocked_auto_removes_after_30s', () async {
    // Given
    const entryId = 'entry-123';
    final notifier = container.read(unlockedEntriesProvider.notifier);

    // When
    notifier.markUnlocked(entryId);
    var state = container.read(unlockedEntriesProvider);
    expect(state, contains(entryId));

    // Wait 31 seconds
    await Future.delayed(Duration(seconds: 31));

    // Then
    state = container.read(unlockedEntriesProvider);
    expect(state, isNot(contains(entryId)));
  });

  test('multiple_entries_tracked_independently', () async {
    // Given
    const entryId1 = 'entry-1';
    const entryId2 = 'entry-2';
    final notifier = container.read(unlockedEntriesProvider.notifier);

    // When
    notifier.markUnlocked(entryId1);
    await Future.delayed(Duration(seconds: 15));
    notifier.markUnlocked(entryId2);

    // Then (both present)
    var state = container.read(unlockedEntriesProvider);
    expect(state, contains(entryId1));
    expect(state, contains(entryId2));

    // Wait for entryId1 to auto-clear (15 more seconds, total 30)
    await Future.delayed(Duration(seconds: 16));
    state = container.read(unlockedEntriesProvider);
    expect(state, isNot(contains(entryId1)));
    expect(state, contains(entryId2)); // Still there
  });
});
```

---

## 4. Integration Tests

### 4.1 Entry Protection Flow

```dart
group('Integration - Entry Protection Flow', () {
  late AppDatabase database;
  late EntryAuthService authService;
  late EntryRepository entryRepository;

  setUp(() async {
    // Setup in-memory DB for testing
    database = AppDatabase.testInstance();
    authService = EntryAuthService();
    entryRepository = EntryRepository(database);
  });

  test('create_protected_entry_stores_encrypted_in_db', () async {
    // Given
    const password = 'MyMasterPassword123!';
    final salt = authService.generateSalt();
    await database.createMasterPasswordConfig(
      passwordHashArgon2: authService.hashPassword(password, salt),
      saltHex: salt,
    );

    final derivedKey = await authService.deriveMasterKey(password, salt);
    const plaintext = 'MySecretPassword';
    final encrypted = authService.encrypt(plaintext, derivedKey);

    const newEntry = Entry(
      id: 'entry-1',
      topicKey: 'social-media',
      type: 'password',
      title: 'Twitter',
      secret: plaintext,
      requiresAuth: true,
      encryptedSecret: encrypted.encryptedSecret,
      cipherNonce: encrypted.nonce,
      cipherTag: encrypted.tag,
    );

    // When
    await entryRepository.createEntry(newEntry);

    // Then
    final retrieved = await entryRepository.getEntry('entry-1');
    expect(retrieved, isNotNull);
    expect(retrieved!.requiresAuth, isTrue);
    expect(retrieved.encryptedSecret, isNotEmpty);
    expect(retrieved.cipherNonce, isNotEmpty);
    expect(retrieved.cipherTag, isNotEmpty);
  });

  test('first_protection_creates_master_password_config', () async {
    // Given
    const password = 'MyMasterPassword123!';

    // When
    final salt = authService.generateSalt();
    final hash = authService.hashPassword(password, salt);
    await database.createMasterPasswordConfig(
      passwordHashArgon2: hash,
      saltHex: salt,
    );

    // Then
    final config = await database.getMasterPasswordConfig();
    expect(config, isNotNull);
    expect(config!.passwordHashArgon2, isNotEmpty);
    expect(config.saltHex, isNotEmpty);
  });

  test('decrypt_protected_entry_from_db', () async {
    // Given (setup from previous test)
    const password = 'MyMasterPassword123!';
    final salt = authService.generateSalt();
    await database.createMasterPasswordConfig(
      passwordHashArgon2: authService.hashPassword(password, salt),
      saltHex: salt,
    );

    final derivedKey = await authService.deriveMasterKey(password, salt);
    const plaintext = 'MySecretPassword';
    final encrypted = authService.encrypt(plaintext, derivedKey);

    const newEntry = Entry(
      id: 'entry-1',
      topicKey: 'social-media',
      type: 'password',
      title: 'Twitter',
      secret: plaintext,
      requiresAuth: true,
      encryptedSecret: encrypted.encryptedSecret,
      cipherNonce: encrypted.nonce,
      cipherTag: encrypted.tag,
    );

    await entryRepository.createEntry(newEntry);

    // When
    final retrieved = await entryRepository.getEntry('entry-1');
    final decrypted = authService.decrypt(
      retrieved!.encryptedSecret!,
      retrieved.cipherNonce!,
      retrieved.cipherTag!,
      derivedKey,
    );

    // Then
    expect(decrypted, equals(plaintext));
  });

  test('unprotected_entries_unchanged', () async {
    // Given
    const unprotectedEntry = Entry(
      id: 'entry-1',
      topicKey: 'notes',
      type: 'note',
      title: 'My Note',
      secret: 'Note content', // Not encrypted
      requiresAuth: false,
      encryptedSecret: null,
      cipherNonce: null,
      cipherTag: null,
    );

    // When
    await entryRepository.createEntry(unprotectedEntry);

    // Then
    final retrieved = await entryRepository.getEntry('entry-1');
    expect(retrieved!.requiresAuth, isFalse);
    expect(retrieved.encryptedSecret, isNull);
    expect(retrieved.cipherNonce, isNull);
    expect(retrieved.cipherTag, isNull);
    expect(retrieved.secret, equals('Note content')); // Plaintext
  });

  test('search_returns_protected_entries_with_indicator', () async {
    // Given (protected + unprotected entries)
    const password = 'MyMasterPassword123!';
    final salt = authService.generateSalt();
    await database.createMasterPasswordConfig(
      passwordHashArgon2: authService.hashPassword(password, salt),
      saltHex: salt,
    );

    // Create unprotected entry
    const unprotected = Entry(
      id: 'entry-1',
      topicKey: 'notes',
      type: 'note',
      title: 'Public Note',
      secret: 'password123',
      requiresAuth: false,
    );
    await entryRepository.createEntry(unprotected);

    // Create protected entry
    final derivedKey = await authService.deriveMasterKey(password, salt);
    final encrypted = authService.encrypt('password123', derivedKey);
    const protected = Entry(
      id: 'entry-2',
      topicKey: 'passwords',
      type: 'password',
      title: 'Secret Password',
      secret: 'password123',
      requiresAuth: true,
      encryptedSecret: encrypted.encryptedSecret,
      cipherNonce: encrypted.nonce,
      cipherTag: encrypted.tag,
    );
    await entryRepository.createEntry(protected);

    // When
    final results = await entryRepository.search('password123');

    // Then
    expect(results.length, equals(2));
    expect(
      results.firstWhere((e) => e.id == 'entry-1').requiresAuth,
      isFalse,
    );
    expect(
      results.firstWhere((e) => e.id == 'entry-2').requiresAuth,
      isTrue,
    );
  });
});
```

---

## 5. Widget Tests

### 5.1 EntryDetailView Tests

```dart
group('Widget - EntryDetailView', () {
  testWidgets('show_reveal_button_if_protected', (WidgetTester tester) async {
    // Given
    const entry = Entry(
      id: 'entry-1',
      topicKey: 'passwords',
      type: 'password',
      title: 'Twitter',
      secret: 'encrypted-secret',
      requiresAuth: true,
      encryptedSecret: 'encrypted',
      cipherNonce: 'nonce',
      cipherTag: 'tag',
    );

    // When
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EntryDetailView(entry: entry),
        ),
      ),
    );

    // Then
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.text('Reveal Secret'), findsOneWidget);
  });

  testWidgets('hide_reveal_button_if_unprotected', (WidgetTester tester) async {
    // Given
    const entry = Entry(
      id: 'entry-1',
      topicKey: 'notes',
      type: 'note',
      title: 'My Note',
      secret: 'plaintext-content',
      requiresAuth: false,
    );

    // When
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EntryDetailView(entry: entry),
        ),
      ),
    );

    // Then
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.text('Reveal Secret'), findsNothing);
    expect(find.text('plaintext-content'), findsOneWidget);
  });

  testWidgets('reveal_button_opens_sheet', (WidgetTester tester) async {
    // Given
    const entry = Entry(
      id: 'entry-1',
      topicKey: 'passwords',
      type: 'password',
      title: 'Twitter',
      secret: 'secret',
      requiresAuth: true,
      encryptedSecret: 'encrypted',
      cipherNonce: 'nonce',
      cipherTag: 'tag',
    );

    // When
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EntryDetailView(entry: entry),
        ),
      ),
    );

    await tester.tap(find.text('Reveal Secret'));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(RevealSecretSheet), findsOneWidget);
  });
});
```

### 5.2 CreateEntryForm Tests

```dart
group('Widget - CreateEntryForm', () {
  testWidgets('protect_toggle_visible', (WidgetTester tester) async {
    // When
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateEntryForm(),
        ),
      ),
    );

    // Then
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Protect this entry'), findsOneWidget);
  });

  testWidgets('toggle_on_shows_setup_dialog_first_time', (WidgetTester tester) async {
    // When
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateEntryForm(),
        ),
      ),
    );

    // Toggle ON
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Then
    expect(find.byType(MasterPasswordSetupDialog), findsOneWidget);
  });
});
```

---

## 6. E2E Tests

### 6.1 Full User Journey

```dart
group('E2E - Full User Journeys', () {
  testWidgets('user_creates_protected_entry_views_unlocks', 
    (WidgetTester tester) async {
    // Scenario: User creates their first protected entry

    // Given (App started)
    await tester.pumpWidget(const TaulApp());

    // When: User creates entry
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter title
    await tester.enterText(find.byType(TextField).first, 'Twitter Password');

    // Enter secret
    await tester.enterText(find.byType(TextField).last, 'MyPassword123!');

    // Toggle protect
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Then: Master password setup dialog shows
    expect(find.byType(MasterPasswordSetupDialog), findsOneWidget);

    // User sets master password
    await tester.enterText(
      find.byType(PasswordField).first, 
      'MasterPassword123!',
    );
    await tester.enterText(
      find.byType(PasswordField).last, 
      'MasterPassword123!',
    );
    await tester.tap(find.text('Set & Protect'));
    await tester.pumpAndSettle();

    // When: User saves entry
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Then: Entry is saved
    expect(find.text('Twitter Password'), findsOneWidget);

    // When: User opens entry again
    await tester.tap(find.text('Twitter Password'));
    await tester.pumpAndSettle();

    // Then: Reveal button shows
    expect(find.text('Reveal Secret'), findsOneWidget);

    // When: User clicks Reveal
    await tester.tap(find.text('Reveal Secret'));
    await tester.pumpAndSettle();

    // Then: Password sheet shows
    expect(find.byType(RevealSecretSheet), findsOneWidget);

    // User enters master password
    await tester.enterText(find.byType(PasswordField), 'MasterPassword123!');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    // Then: Secret is revealed
    expect(find.text('MyPassword123!'), findsOneWidget);
  });

  testWidgets('user_searches_protected_entries', (WidgetTester tester) async {
    // Scenario: User searches and finds protected entries

    // Given (App with existing protected entry)
    // (setup from previous test)

    // When: User searches for "password"
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchField), 'password');
    await tester.pumpAndSettle();

    // Then: Results show 🔒 indicator
    expect(find.text('🔒'), findsWidgets);
  });
});
```

---

## 7. Test Coverage Goals

```
┌─────────────────────────────────────────────┐
│ Test Coverage Targets                       │
├─────────────────────────────────────────────┤
│ EntryAuthService         → 90%+             │
│ Riverpod Providers       → 85%+             │
│ Database Layer           → 80%+             │
│ UI Widgets               → 75%+             │
│ Integration Flows        → 85%+             │
├─────────────────────────────────────────────┤
│ OVERALL                  → ≥80%             │
│ Critical Paths           → 100%             │
│ (encrypt/decrypt/verify)                    │
└─────────────────────────────────────────────┘

Critical Paths (100% coverage):
✅ encrypt() method
✅ decrypt() method
✅ deriveMasterKey() method
✅ masterPasswordProvider.setMasterPassword()
✅ EntryDetailView.buildRevealButton()
✅ RevealSecretSheet.onUnlock()
```

---

## 8. Test Execution & CI/CD

### 8.1 Test Commands

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate coverage report
lcov --summary coverage/lcov.info

# Run specific suite
flutter test test/services/entry_auth_service_test.dart

# Run with verbose output
flutter test -v

# Run tests matching pattern
flutter test --name="encrypt"
```

### 8.2 CI/CD Pipeline

```yaml
name: Test & Coverage

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - run: flutter pub get
      
      - run: flutter test --coverage
      
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          
      - name: Check coverage threshold
        run: |
          # Verify coverage >= 80%
          lcov --summary coverage/lcov.info | grep "lines" | grep -E "80\.|8[1-9]\.|9[0-9]\.|100\."
```

---

## 9. Test Data & Fixtures

### 9.1 Test Fixtures (Dart)

```dart
class TestFixtures {
  static const masterPassword = 'TestMasterPassword123!';
  static const salt = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';
  
  static const plaintext = 'MySecretPassword123!';
  static const unicode = 'Contraseña123!🔒';
  static const largeSecret = 'A' * 100000;
  static const emptySecret = '';

  static final Entry protectedEntry = Entry(
    id: 'entry-1',
    topicKey: 'passwords',
    type: 'password',
    title: 'Test Password',
    secret: plaintext,
    requiresAuth: true,
    encryptedSecret: 'encrypted-abc123',
    cipherNonce: 'nonce-def456',
    cipherTag: 'tag-ghi789',
  );

  static final Entry unprotectedEntry = Entry(
    id: 'entry-2',
    topicKey: 'notes',
    type: 'note',
    title: 'Test Note',
    secret: 'Plaintext content',
    requiresAuth: false,
  );

  static final MasterPasswordConfig config = MasterPasswordConfig(
    passwordHashArgon2: 'hash-abc123',
    saltHex: salt,
  );
}
```

---

## 10. Test Execution Timeline

| Phase | Duración | Tareas |
|-------|----------|--------|
| **Unit Tests** | 1h | EntryAuthService + Providers |
| **Integration** | 0.5h | DB + Encryption flows |
| **Widget Tests** | 0.5h | UI components |
| **E2E Tests** | 0.5h | Full user journeys |
| **Coverage Report** | 0.2h | Generate & verify 80%+ |
| **CI/CD Setup** | 0.3h | GitHub Actions pipeline |
| **TOTAL** | **~3h** | Incluido en 20h totales |

---

## Summary

✅ **Total Tests:** 40-50 (unit, integration, widget, E2E)  
✅ **Coverage:** ≥80% overall, 100% critical paths  
✅ **Effort:** 2-3 horas (parte de 20h)  
✅ **Automation:** Full CI/CD pipeline  
✅ **Quality Gates:** Coverage, performance benchmarks  

---

**Documento:** `PHASE_2_TESTING_STRATEGY_v2_SIMPLIFIED.md`  
**Fecha:** 2025  
**Responsable:** QA Team
