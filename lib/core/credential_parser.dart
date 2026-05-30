class ParsedCredential {
  final String service;
  final String username;
  final String password;
  final String url;
  final List<String> tags;

  const ParsedCredential({
    required this.service,
    required this.username,
    required this.password,
    this.url = '',
    this.tags = const [],
  });
}

class CredentialParser {
  /// Parses "servicio*user*pass*url -#tag1 -#tag2" into fields.
  /// Fields are separated by `*` (no spaces in credential part).
  /// URL is optional — 4th `*`-segment if present.
  /// Tags use `-#tag` syntax, space-separated after the credential.
  /// Also supports legacy formats for backward compatibility.
  /// Returns null if no password found.
  static ParsedCredential? parse(String text) {
    // Extract -#tags first
    final tagRe = RegExp(r'-#([\w-]+)');
    final tagMatches = tagRe.allMatches(text);
    final tags = tagMatches.map((m) => m.group(1)!).toList();
    final withoutTags = text.replaceAll(tagRe, ' ').trim();

    // Extract legacy ;#tags
    final legacyTagRe = RegExp(r';#([\w-]+)');
    final legacyTagMatches = legacyTagRe.allMatches(withoutTags);
    for (final m in legacyTagMatches) {
      tags.add(m.group(1)!);
    }
    final cleaned = withoutTags.replaceAll(legacyTagRe, ' ').trim();

    // Normalize legacy comma format: replace commas with nothing (fields use *)
    // and handle space-separated * segments like "Gmail *user *pass"
    final normalized = cleaned
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s*\*\s*'), '*')
        .trim();

    // Split by * for credential fields
    final rawSegments = normalized.split('*').where((s) => s.trim().isNotEmpty).toList();
    if (rawSegments.isEmpty) return null;

    // If only 1 segment (no * found), try legacy comma format
    if (rawSegments.length == 1) {
      return _parseLegacyComma(text);
    }

    // Expand segments that embed a URL after a space (e.g. "pass https://url" or "pass url.com")
    final starSegments = <String>[];
    for (final seg in rawSegments) {
      final trimmed = seg.trim();
      // Match: text + space + something with a dot (URL, domain, IP)
      final urlMatch = RegExp(r'^(.+?)\s+(\S+\..+)$').firstMatch(trimmed);
      if (urlMatch != null) {
        starSegments.add(urlMatch.group(1)!);
        starSegments.add(urlMatch.group(2)!);
      } else {
        starSegments.add(trimmed);
      }
    }

    final service = starSegments[0].trim();
    if (service.isEmpty) return null;

    // Collect non-tag, non-URL segments after service
    final fieldSegments = <String>[];
    String url = '';
    for (var i = 1; i < starSegments.length; i++) {
      final seg = starSegments[i].trim();
      if (seg.isEmpty) continue;
      if (seg.contains('://') || seg.startsWith('http') || _looksLikeDomain(seg)) {
        url = seg;
      } else {
        fieldSegments.add(seg);
      }
    }

    if (fieldSegments.isEmpty) return null;

    final String username;
    final String password;
    if (fieldSegments.length == 1) {
      // Only password provided — username defaults to service
      username = service;
      password = fieldSegments[0];
    } else {
      username = fieldSegments[0];
      password = fieldSegments[1];
    }

    return ParsedCredential(
      service: service,
      username: username,
      password: password,
      url: url,
      tags: tags,
    );
  }

  /// Legacy parser for comma-separated format: "servicio,*user,*pass,;#tag"
  static ParsedCredential? _parseLegacyComma(String text) {
    final segments = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    final service = segments.first;
    final asteriskSegments = <String>[];
    final tags = <String>[];

    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.startsWith(';#')) {
        tags.add(segment.substring(2));
      } else if (segment.startsWith('#')) {
        tags.add(segment.substring(1));
      } else if (segment.startsWith('*')) {
        asteriskSegments.add(segment.substring(1));
      }
    }

    if (asteriskSegments.isEmpty) return null;

    final String username;
    final String password;
    if (asteriskSegments.length == 1) {
      username = service;
      password = asteriskSegments.first;
    } else {
      username = asteriskSegments[0];
      password = asteriskSegments[1];
    }

    return ParsedCredential(
      service: service,
      username: username,
      password: password,
      tags: tags,
    );
  }

  /// Returns true if the segment looks like a domain name (contains a dot).
  /// Handles bare URLs like "mail.google.com", IPs like "192.168.1.1".
  static bool _looksLikeDomain(String s) {
    return s.contains('.') && !s.startsWith('-#');
  }

  /// Masks a username: shows last 4 chars with **** prefix.
  /// "fidel45" -> "****el45", "ab" -> "**ab"
  static String maskUsername(String username) {
    if (username.length <= 4) {
      return '*$username';
    }
    return '****${username.substring(username.length - 4)}';
  }
}
