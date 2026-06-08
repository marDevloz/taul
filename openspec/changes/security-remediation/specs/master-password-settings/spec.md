# Delta: Master Password Settings (R7 Modification)

## MODIFIED Requirements

### R7: No DEK leakage

DEK MUST reside in memory only. The DEK Uint8List buffer MUST be zeroed with `fillRange(0, length, 0)` before the reference is set to null. DEK MUST NEVER be logged, stored plaintext, or left in memory after use.

(Previously: DEK in memory only. Zero after use. Never logged or stored plaintext.)

#### Scenario: DEK zeroed after use

- GIVEN a DEK Uint8List is in memory after an operation
- WHEN `clearCachedDek()` is called
- THEN the buffer bytes are all 0x00
- AND the reference is set to null

#### Scenario: DEK not logged

- GIVEN DEK is in memory during any operation
- WHEN any log statement executes
- THEN the DEK value does not appear in log output

#### Scenario: DEK not stored to disk

- GIVEN DEK is in memory
- WHEN the operation completes
- THEN no file on disk contains the DEK in plaintext
