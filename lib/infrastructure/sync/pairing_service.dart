import 'dart:io';
import 'dart:math';

class PairingService {
  static const _maxAttempts = 3;
  final Random _random = Random.secure();
  String? _currentCode;
  int _failedAttempts = 0;
  bool _lockedOut = false;

  String generateCode() {
    final code = _random.nextInt(900000) + 100000;
    _currentCode = code.toString();
    _failedAttempts = 0;
    _lockedOut = false;
    return _currentCode!;
  }

  bool validateCode(String input) {
    if (_lockedOut) return false;
    if (input == _currentCode) {
      _failedAttempts = 0;
      return true;
    }
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) _lockedOut = true;
    return false;
  }

  bool get isLockedOut => _lockedOut;
  int get failedAttempts => _failedAttempts;
  int get maxAttempts => _maxAttempts;

  String generateQrData(String ip, int port) => 'https://$ip:$port';

  Future<String> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && addr.address.isNotEmpty) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }
}
