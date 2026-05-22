# Taúl Coding Standards

## Architecture & Design
- Follow Clean Architecture: data → domain → presentation layers
- Prefer composition over inheritance
- Keep classes small, focused, single responsibility
- Use repository pattern for data access
- Avoid global state — use dependency injection

## Flutter/Dart
- Use `const` constructors whenever possible
- Prefer `final` over `var` for local variables
- Use `enum` instead of constant strings for finite states
- Avoid `late` — prefer constructor initialization
- Use named constructors over factory when possible
- Keep widgets pure — extract business logic to controllers/blocs
- Use `go_router` for navigation

## State Management
- Favor simple state: ValueNotifier, ChangeNotifier
- Avoid over-engineering — use streams only when needed
- Keep state close to where it's used

## Security
- Never log secrets or encryption keys
- Use AES-256-GCM for encryption
- Use Argon2id for key derivation
- Zero secrets in source code

## Testing
- Write unit tests for domain layer
- Write widget tests for presentation layer
- Name tests: `should_do_thing_when_condition`
- Keep tests simple and readable

## Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Private members: `_camelCase`

## Do NOT
- Use `print()` — use a logger
- Use `dynamic` — prefer typed generics
- Ignore analyzer warnings
- Commit commented-out code
- Use `async` on void main()
