import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

/// Manages a self-signed X.509 certificate for HTTPS sync.
///
/// Stores sync_cert.pem + sync_key.pem in the app documents directory.
/// Generates RSA 2048 / SHA-256 on first use; regenerates if corrupt.
class CertificateManager {
  static const _certFile = 'sync_cert.pem';
  static const _keyFile = 'sync_key.pem';

  final Directory _appDir;

  CertificateManager({required Directory appDir}) : _appDir = appDir;

  static Future<CertificateManager> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return CertificateManager(appDir: dir);
  }

  Future<SecurityContext> getContext() async {
    final certPath = '${_appDir.path}/$_certFile';
    final keyPath = '${_appDir.path}/$_keyFile';

    final certExists = await File(certPath).exists();
    final keyExists = await File(keyPath).exists();

    if (!certExists || !keyExists || !await _isCertValid(certPath)) {
      await _generateCert();
    }

    return SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
  }

  Future<List<int>> getFingerprint() async {
    final certPath = '${_appDir.path}/$_certFile';
    if (!await File(certPath).exists()) await _generateCert();
    final pem = await File(certPath).readAsString();
    final body = pem
        .replaceAll(RegExp(r'-----BEGIN CERTIFICATE-----'), '')
        .replaceAll(RegExp(r'-----END CERTIFICATE-----'), '')
        .replaceAll(RegExp(r'\s'), '');
    return base64Decode(body);
  }

  Future<bool> _isCertValid(String certPath) async {
    try {
      final content = await File(certPath).readAsString();
      return content.contains('BEGIN CERTIFICATE') &&
          content.contains('END CERTIFICATE');
    } catch (_) {
      return false;
    }
  }

  Future<void> _generateCert() async {
    final secureRandom = _secureRandom();
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64);
    final keyGenerator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));
    final kp = keyGenerator.generateKeyPair();
    final pub = kp.publicKey;
    final priv = kp.privateKey;

    final now = DateTime.now();
    final certDer = _buildCert(pub, priv, now, now.add(const Duration(days: 365)));
    await File('${_appDir.path}/$_certFile').writeAsString(_pem('CERTIFICATE', certDer));
    await File('${_appDir.path}/$_keyFile').writeAsString(_pem('RSA PRIVATE KEY', _encodePrivKey(priv)));
  }

  // ── X.509 cert builder (minimal self-signed) ──

  Uint8List _buildCert(RSAPublicKey pub, RSAPrivateKey priv, DateTime from, DateTime to) {
    final tbs = _tbs(pub, from, to);
    final alg = _sha256RsaAlg();
    final sig = _sign(tbs, priv);
    return _seq([tbs, alg, _bitStr(sig)]);
  }

  Uint8List _tbs(RSAPublicKey pub, DateTime from, DateTime to) {
    final v = _int(BigInt.from(2)); // version 3
    final serial = _int(BigInt.from(DateTime.now().microsecondsSinceEpoch));
    final alg = _sha256RsaAlg();
    final name = _name('Taul Sync');
    final validity = _seq([_utc(from), _utc(to)]);
    final spki = _spki(pub);
    return _seq([_tag(0xa0, [v]), serial, alg, name, validity, name, spki]);
  }

  Uint8List _sha256RsaAlg() =>
      _seq([_oid('1.2.840.113549.1.1.11'), _null()]);

  Uint8List _name(String cn) {
    final attr = _seq([_oid('2.5.4.3'), _utf8(cn)]);
    return _seq([_set([attr])]);
  }

  Uint8List _spki(RSAPublicKey pub) {
    final rsaKey = _seq([_int(pub.n!), _int(pub.publicExponent!)]);
    final rsaAlg = _seq([_oid('1.2.840.113549.1.1.1'), _null()]);
    return _seq([rsaAlg, _bitStr(rsaKey)]);
  }

  Uint8List _encodePrivKey(RSAPrivateKey k) {
    return _seq([
      _int(BigInt.zero),
      _int(k.n!), _int(k.publicExponent!), _int(k.privateExponent!),
      _int(k.p!), _int(k.q!),
      _int(k.privateExponent! % (k.p! - BigInt.from(1))),
      _int(k.privateExponent! % (k.q! - BigInt.from(1))),
      _int(_modInverse(k.q!, k.p!)),
    ]);
  }

  BigInt _modInverse(BigInt a, BigInt m) {
    var t = BigInt.zero, newt = BigInt.one;
    var r = m, newr = a;
    while (newr != BigInt.zero) {
      final q = r ~/ newr;
      final tmp = t; t = newt; newt = tmp - q * newt;
      final tmp2 = r; r = newr; newr = tmp2 - q * newr;
    }
    if (r > BigInt.from(1)) throw Exception('not invertible');
    if (t < BigInt.zero) t += m;
    return t;
  }

  Uint8List _sign(Uint8List data, RSAPrivateKey key) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(key));
    return signer.generateSignature(data).bytes;
  }

  // ── DER primitives ──

  Uint8List _int(BigInt v) {
    var b = _bigIntBytes(v);
    if (b[0] & 0x80 != 0) {
      final p = Uint8List(b.length + 1)..setAll(1, b);
      b = p;
    }
    return _tagBytes(0x02, b);
  }

  Uint8List _utf8(String s) => _tagBytes(0x0c, Uint8List.fromList(utf8.encode(s)));

  Uint8List _null() => _tagBytes(0x05, Uint8List(0));

  Uint8List _utc(DateTime dt) {
    final s = '${(dt.year % 100).toString().padLeft(2, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}Z';
    return _tagBytes(0x17, Uint8List.fromList(utf8.encode(s)));
  }

  Uint8List _oid(String dotted) {
    final parts = dotted.split('.').map(int.parse).toList();
    final body = <int>[parts[0] * 40 + parts[1]];
    for (var i = 2; i < parts.length; i++) {
      var v = parts[i];
      if (v < 128) {
        body.add(v);
      } else {
        final tmp = <int>[];
        while (v > 0) {
          tmp.insert(0, v & 0x7f);
          v >>= 7;
        }
        for (var j = 0; j < tmp.length - 1; j++) {
          body.add(tmp[j] | 0x80);
        }
        body.add(tmp.last);
      }
    }
    return _tagBytes(0x06, Uint8List.fromList(body));
  }

  Uint8List _bitStr(Uint8List data) =>
      _tagBytes(0x03, Uint8List.fromList([0x00, ...data]));

  Uint8List _set(List<Uint8List> items) => _tagBytes(0x31, _concat(items));

  Uint8List _seq(List<Uint8List> items) => _tagBytes(0x30, _concat(items));

  Uint8List _tag(int tag, List<Uint8List> items) => _tagBytes(tag, _concat(items));

  Uint8List _tagBytes(int tag, Uint8List content) {
    final len = _encodeLength(content.length);
    final r = Uint8List(1 + len.length + content.length);
    r[0] = tag;
    r.setAll(1, len);
    r.setAll(1 + len.length, content);
    return r;
  }

  Uint8List _encodeLength(int l) {
    if (l < 0x80) return Uint8List.fromList([l]);
    if (l < 0x100) return Uint8List.fromList([0x81, l]);
    if (l < 0x10000) return Uint8List.fromList([0x82, l >> 8, l & 0xff]);
    return Uint8List.fromList([0x83, l >> 16, (l >> 8) & 0xff, l & 0xff]);
  }

  Uint8List _concat(List<Uint8List> parts) {
    final total = parts.fold(0, (s, p) => s + p.length);
    final r = Uint8List(total);
    var off = 0;
    for (final p in parts) {
      r.setAll(off, p);
      off += p.length;
    }
    return r;
  }

  Uint8List _bigIntBytes(BigInt v) {
    if (v == BigInt.zero) return Uint8List(1);
    final hex = v.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final b = Uint8List(padded.length ~/ 2);
    for (var i = 0; i < b.length; i++) {
      b[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return b;
  }

  String _pem(String label, Uint8List der) {
    final b64 = base64Encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, (i + 64).clamp(0, b64.length)));
    }
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }

  SecureRandom _secureRandom() {
    final sr = SecureRandom('Fortuna');
    sr.seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256))),
    ));
    return sr;
  }
}
