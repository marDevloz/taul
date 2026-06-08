# Delta: Encrypted Export (PR3 — Finding D)

## ADDED Requirements

### R1: Export passphrase prompt

The system SHALL prompt the user for a passphrase before producing an encrypted export. The passphrase MUST be at least 8 characters. The prompt SHALL include a confirmation field.

#### Scenario: Valid passphrase accepted

- GIVEN user enters "MySecretPass123" in both passphrase fields
- WHEN export is initiated
- THEN the export proceeds with the provided passphrase
- AND the passphrase is not stored or logged

#### Scenario: Mismatched passphrases rejected

- GIVEN user enters "pass1" in first field and "pass2" in confirmation
- WHEN export is initiated
- THEN the export is rejected with "Passphrases do not match"

#### Scenario: Short passphrase rejected

- GIVEN user enters "abc" (3 chars) in passphrase field
- WHEN export is initiated
- THEN the export is rejected with "Passphrase must be at least 8 characters"

### R2: Encrypted export format

The system SHALL produce a JSON file with structure: `{version: 2, salt_hex, nonce_hex, tag_hex, ciphertext_hex}`. The `ciphertext_hex` is AES-256-GCM encryption of the full JSON export payload (title, content, tags, metadata).

#### Scenario: Encrypted file structure

- GIVEN user provides a valid passphrase
- WHEN export completes
- THEN the output file contains `version`, `salt_hex`, `nonce_hex`, `tag_hex`, `ciphertext_hex` fields
- AND the file extension is `.json`

### R3: Key derivation for export

The system SHALL derive the encryption key from the passphrase using Argon2id with a random 16-byte salt. The derived key is used for AES-256-GCM encryption.

#### Scenario: Same passphrase produces different ciphertext

- GIVEN two exports with the same passphrase
- WHEN both exports are generated
- THEN the `salt_hex` and `nonce_hex` values differ between exports
- AND the `ciphertext_hex` values differ

### R4: Import with passphrase

The system SHALL prompt for a passphrase when importing an encrypted export. On correct passphrase, the system decrypts and imports all entries.

#### Scenario: Correct passphrase import

- GIVEN an encrypted export file and correct passphrase
- WHEN import is initiated
- THEN all entries are decrypted and imported
- AND the entry count matches the original export

#### Scenario: Wrong passphrase import

- GIVEN an encrypted export file and incorrect passphrase
- WHEN import is initiated
- THEN the system displays "Incorrect passphrase" and no entries are imported

#### Scenario: Plaintext import fallback

- GIVEN a legacy plaintext export (version 1 or no version field)
- WHEN import is initiated
- THEN the system imports without prompting for a passphrase

### R5: Backward compatibility

The system SHALL continue to support importing plaintext (version 1) exports. The `version` field distinguishes encrypted (v2) from plaintext (v1) exports.

#### Scenario: V1 import still works

- GIVEN a plaintext export file from a previous version
- WHEN import is initiated
- THEN entries are imported successfully without passphrase
