enum SyncState {
  idle,
  connecting,
  pairing,
  syncing,
  complete,
  error;

  bool get isActive => this == connecting || this == pairing || this == syncing;

  bool get canStart => this == idle || this == complete || this == error;

  bool get showProgress =>
      this == connecting ||
      this == pairing ||
      this == syncing ||
      this == complete;
}
