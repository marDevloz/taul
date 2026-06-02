# Task Type Specification

## Purpose

Define the `EntryType.task` entry type with completion lifecycle and persistent `completedAt` field across all layers.

## Requirements

### Requirement: Task entry type

The system MUST add `EntryType.task` to the `EntryType` enum with label `"TAREA"`.

The existing `Entry` entity MUST gain an optional `DateTime? completedAt` field.

The system MUST provide a migration from schema version 7 to 8 that adds a nullable `completed_at` column to the `entries` table.

#### Scenario: Task type available in type filter

- GIVEN an entry exists with `type == EntryType.task`
- WHEN the user filters entries by type via the SnakeFab
- THEN a "Tasks" option SHALL be present alongside Notes, Ideas, Glossary
- AND the entry SHALL appear when that filter is selected

#### Scenario: New task has no completedAt

- GIVEN a new entry is created with `type == EntryType.task`
- WHEN the entry is persisted
- THEN `completedAt` MUST be `null`

#### Scenario: completedAt persisted across sessions

- GIVEN a task entry with a non-null `completedAt`
- WHEN the database is reopened
- THEN the field SHALL retain its value

#### Scenario: Task in migration from schema 7

- GIVEN a database at schema version 7 with existing entries
- WHEN the database is upgraded to schema 8
- THEN all existing rows SHALL have `completed_at` set to `null`

### Requirement: Task completion lifecycle

The system MUST support marking a task as complete: remove `#pendiente`, add `#completada`, and set `completedAt` to the current timestamp.

If a user removes the `#pendiente` system tag from a task that does NOT have `#completada`, the system MUST re-add `#pendiente` automatically.

#### Scenario: Mark task complete

- GIVEN a task entry with `tags` containing `"#pendiente"` and `completedAt == null`
- WHEN the user marks the task as complete
- THEN `#pendiente` MUST be removed from the entry's tags
- AND `#completada` MUST be added
- AND `completedAt` MUST be set to the current UTC time

#### Scenario: Auto-reattach pendiente

- GIVEN a task entry whose `tags` do NOT contain `"#pendiente"` and do NOT contain `"#completada"` and `completedAt` is `null`
- WHEN the entry is saved
- THEN `#pendiente` MUST be re-added to the entry's tags

#### Scenario: Non-task entries unaffected

- GIVEN an entry with `type != EntryType.task`
- WHEN the user saves the entry
- THEN the system MUST NOT add or remove `#pendiente` or `#completada` system tags
- AND `completedAt` SHALL remain unchanged

### Requirement: Task auto-creates with pendiente

The system MUST automatically assign the `#pendiente` system tag to every newly created task entry.

#### Scenario: New task gets pendiente

- GIVEN a user creates a new entry of type `task`
- WHEN the entry is persisted
- THEN `tags` MUST include `"#pendiente"`

#### Scenario: Pendiente not assigned to other types

- GIVEN a user creates a new entry of type `note`, `idea`, `glossary`, or `credential`
- WHEN the entry is persisted
- THEN `tags` MUST NOT include `"#pendiente"` unless explicitly added by the user
