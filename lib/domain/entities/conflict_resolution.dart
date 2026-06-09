enum ConflictResolution {
  pending('PENDING'),
  keepLocal('KEEP_LOCAL'),
  keepRemote('KEEP_REMOTE'),
  keepBoth('KEEP_BOTH');

  final String label;
  const ConflictResolution(this.label);

  static ConflictResolution fromLabel(String label) {
    return ConflictResolution.values.firstWhere(
      (e) => e.label == label,
      orElse: () => ConflictResolution.pending,
    );
  }
}