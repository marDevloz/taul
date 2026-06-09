enum SyncState {
  idle,
  pairing,
  syncing,
  complete,
  error;

  bool get isActive => this == pairing || this == syncing;

  bool get canStart => this == idle || this == complete || this == error;

  bool get showProgress => this == pairing || this == syncing || this == complete;
}
