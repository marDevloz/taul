enum SyncState {
  idle,
  pairing,
  syncing,
  complete,
  error;

  bool get isActive => this == pairing || this == syncing;
}