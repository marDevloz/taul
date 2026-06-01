# User Manual Specification

## Purpose

In-app offline reference documenting Taúl features — entry types, quick-add syntax, tags, merge, credential protection, keyboard shortcuts, and settings. Content is embedded Dart rich text in expandable sections.

## Requirements

### Requirement: Quick-Add Syntax Reference

The manual MUST document every quick-add shorthand: entry type prefixes (`#`, `!`, `?`, `.`), tag injection (`+tag`), and secure-tag injection (`++tag`).

#### Scenario: Displays all quick-add modifiers

- GIVEN the user opens the manual
- WHEN the user expands "Quick-Add Syntax"
- THEN the section lists all type prefixes with their meaning and tag injection examples

#### Scenario: Edge case — empty or malformed syntax

- GIVEN the quick-add section is displayed
- WHEN a prefix has no documented meaning (e.g. reserved future prefix)
- THEN it SHOULD be omitted rather than shown with placeholder text

### Requirement: Entry Types

The manual SHALL document every entry type with its icon, prefix, and purpose.

#### Scenario: Lists all entry types

- GIVEN the manual is open
- WHEN the user expands "Entry Types"
- THEN each type shows its prefix character, its icon, and a one-line description

#### Scenario: Discouraged types are called out

- GIVEN the "Entry Types" section is displayed
- WHEN an entry type is deprecated or discouraged
- THEN the manual SHOULD note the deprecation and recommend the replacement

### Requirement: Tags Reference

The manual MUST explain tag creation, color assignment, secure-tag behavior, and autocomplete filtering rules.

#### Scenario: Tag lifecycle summary

- GIVEN the user expands the "Tags" section
- THEN the section describes tag creation, color assignment, secure mode, and prefix-matching autocomplete

#### Scenario: Secure tag visibility boundary

- GIVEN the "Tags" section is displayed
- WHEN the user reads about secure tags
- THEN the manual MUST state that secure tag content is only visible while the vault is unlocked

### Requirement: Merge Entries

The manual SHALL document how to select entries for merge and the merge result behavior.

#### Scenario: Merge workflow described

- GIVEN the user expands "Merge Entries"
- THEN the section explains how to select entries and the rules for combining content and tags

#### Scenario: Destructive merge warning

- GIVEN the merge section is displayed
- WHEN the user reads about merge
- THEN the manual MUST warn that merge is destructive and cannot be undone

### Requirement: Master Password and Security

The manual MUST document credential protection: master password setup, vault locking, AES-256-GCM encryption, and Argon2id key derivation.

#### Scenario: Security summary

- GIVEN the user expands "Credential Protection"
- THEN the section explains how the master password protects crypt entries
- AND it names the encryption algorithm (AES-256-GCM) and key derivation (Argon2id)

#### Scenario: Logged-out state behavior

- GIVEN the security section is displayed
- WHEN the user reads about vault lock
- THEN the manual MUST state that crypt entries and secure tags are hidden while locked

### Requirement: Keyboard Shortcuts

The manual MUST list every keyboard shortcut (global and in-app) with its key combination and action.

#### Scenario: All shortcuts listed

- GIVEN the user expands "Keyboard Shortcuts"
- THEN every shortcut shows its modifier, primary key, and action

#### Scenario: Platform differences noted

- GIVEN the keyboard shortcuts section is displayed
- WHEN a shortcut differs between Windows and the configured platform
- THEN the manual SHOULD note the alternative binding

### Requirement: Settings Overview

The manual SHALL provide a walkthrough of every settings screen option and its effect.

#### Scenario: Settings described

- GIVEN the user expands "Settings Overview"
- THEN every toggle, picker, and action is listed with a plain-language explanation

#### Scenario: Factory-reset warning

- GIVEN the settings overview is displayed
- WHEN the user reads about the "nuke vault" or factory-reset option
- THEN the manual MUST warn that the action is permanent and deletes all data
