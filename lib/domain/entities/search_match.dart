import 'package:taul/domain/entities/entry.dart';

/// Rango `[start, end)` de caracteres a resaltar dentro del texto de un
/// [SearchSnippet]. Apunta sobre el texto del snippet, no sobre el contenido
/// original de la entrada.
typedef HighlightRange = ({int start, int end});

/// Fragmento de contexto alrededor del término buscado, con los rangos que
/// deben resaltarse (offsets sobre [text]).
class SearchSnippet {
  final String text;
  final List<HighlightRange> highlights;

  const SearchSnippet({required this.text, required this.highlights});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchSnippet) return false;
    if (other.text != text) return false;
    if (other.highlights.length != highlights.length) return false;
    for (var i = 0; i < highlights.length; i++) {
      if (other.highlights[i] != highlights[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(text, Object.hashAll(highlights));
}

/// Resultado de búsqueda: la entrada que matcheó, el snippet opcional con el
/// contexto del match (para resaltar el contenido) y los términos usados
/// (para resaltar el título cuando el match cae ahí).
class SearchMatch {
  final Entry entry;
  final SearchSnippet? snippet;
  final List<String> terms;

  const SearchMatch({
    required this.entry,
    this.snippet,
    this.terms = const [],
  });
}
