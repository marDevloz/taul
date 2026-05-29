class ParsedCredential {
  final String service;
  final String username;
  final String password;
  final List<String> tags;

  const ParsedCredential({
    required this.service,
    required this.username,
    required this.password,
    this.tags = const [],
  });
}

class CredentialParser {
  /// Parses "servicio,*usuario,*contraseña,#tag1,tag2" into fields.
  /// Returns null if no password found.
  static ParsedCredential? parse(String text) {
    final segments = text.split(',');
    if (segments.isEmpty) return null;

    final service = segments.first.trim();

    final asteriskSegments = <String>[];
    final tags = <String>[];
    var foundHash = false;

    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i].trim();
      if (foundHash) {
        tags.add(segment);
      } else if (segment.startsWith('#')) {
        foundHash = true;
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

  /// Masks a username: shows last 4 chars with **** prefix.
  /// "fidel45" -> "****el45", "ab" -> "**ab"
  static String maskUsername(String username) {
    if (username.length <= 4) {
      return '*$username';
    }
    return '****${username.substring(username.length - 4)}';
  }
}
