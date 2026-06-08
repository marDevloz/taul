# Delta: Master Password Recovery (R7 Modification)

## MODIFIED Requirements

### R7: No DEK leakage

DEK MUST reside in memory only. The DEK Uint8List buffer MUST be zeroed with `fillRange(0, length, 0)` before the reference is set to null. DEK MUST NEVER be logged, stored plaintext, or left in memory after use.

(Previously: DEK in memory only. Zero after use. Never logged or stored plaintext.)

#### Scenario: DEK zeroed after recovery

- GIVEN a DEK Uint8List is in memory after recovery unwrap
- WHEN the recovery operation completes (success or failure)
- THEN the buffer bytes are all 0x00
- AND the reference is set to null

#### Scenario: DEK not logged during recovery

- GIVEN DEK is in memory during recovery
- WHEN any log statement executes
- THEN the DEK value does not appear in log output

#### Scenario: Partial failure does not leak DEK

- GIVEN recovery fails mid-operation (e.g., DB write error)
- WHEN the failure path executes cleanup
- THEN the DEK buffer is zeroed and reference nulled
- AND no partial DEK data persists in memory
