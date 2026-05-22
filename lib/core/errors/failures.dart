sealed class Failure {
  final String message;
  final Object? cause;

  const Failure({required this.message, this.cause});
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.cause});
}

class EntryNotFoundFailure extends Failure {
  const EntryNotFoundFailure({super.message = 'Entry not found', super.cause});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.cause});
}
