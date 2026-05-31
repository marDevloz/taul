import 'package:flutter/material.dart';

/// Data for a single expandable section in the manual.
class _ManualSection {
  final String title;
  final IconData icon;
  final List<_Paragraph> paragraphs;

  const _ManualSection({
    required this.title,
    required this.icon,
    required this.paragraphs,
  });
}

/// A paragraph inside a manual section — either plain text or a bullet point.
sealed class _Paragraph {}

final class _TextParagraph extends _Paragraph {
  final TextSpan span;
  _TextParagraph(this.span);
}

final class _BulletParagraph extends _Paragraph {
  final TextSpan span;
  _BulletParagraph(this.span);
}

/// Convenience: build a [TextSpan] with optional bold segments.
TextSpan _b(String text) => TextSpan(
      text: text,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );

/// Convenience: build a monospace [TextSpan] for inline code.
TextSpan _c(String text) => TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: Colors.grey.withValues(alpha: 0.15),
      ),
    );

/// Convenience: italic [TextSpan].
TextSpan _i(String text) => TextSpan(
      text: text,
      style: const TextStyle(fontStyle: FontStyle.italic),
    );

/// Shortcut for a plain [TextSpan].
TextSpan _t(String text) => TextSpan(text: text);

/// Build a simple text paragraph from a list of inline spans.
_TextParagraph _p(List<InlineSpan> spans) => _TextParagraph(TextSpan(children: spans));

/// Build a bullet paragraph from a list of inline spans.
_BulletParagraph _bp(List<InlineSpan> spans) => _BulletParagraph(TextSpan(children: spans));

class UserManualScreen extends StatelessWidget {
  const UserManualScreen({super.key});

  static final _sections = <_ManualSection>[
    // ── 1. Inicio rápido ──
    _ManualSection(
      title: 'Inicio rápido',
      icon: Icons.flash_on,
      paragraphs: [
        _p([
          _b('Escribí directamente'),
          _t(
            ' en la pantalla principal para crear una entrada. '
            'Taúl detecta automáticamente el tipo según el formato:',
          ),
        ]),
        _bp([_c('!idea genial'), _t(' → '), _b('Idea'), _t('. El texto después de ! se convierte en el contenido.')]),
        _bp([_c('Título# texto'), _t(' → '), _b('Nota con título'), _t('. Todo antes de # es el título.')]),
        _bp([_c('término:definición'), _t(' → '), _b('Glosario'), _t('. Separa término y definición con dos puntos.')]),
        _bp([_c('servicio*user*pass*url'), _t(' → '), _b('Credencial'), _t('. Campos separados por * (URL opcional).')]),
        _bp([_c('-#etiqueta'), _t(' → agrega una '), _b('etiqueta'), _t(' a la entrada.')]),
        _p([
          _t('También podés usar '),
          _b('Título# '),
          _t('como prefijo de cualquier entrada para asignarle un nombre.'),
        ]),
      ],
    ),

    // ── 2. Tipos de entrada ──
    _ManualSection(
      title: 'Tipos de entrada',
      icon: Icons.category_outlined,
      paragraphs: [
        _p([_b('Nota'), _t(' — el tipo predeterminado. Texto libre sin formato especial. Ideal para apuntes rápidos.')]),
        _p([_b('Idea'), _t(' — comienza con '), _c('!'), _t('. Separada visualmente con estilo de cita para destacar ideas.')]),
        _p([_b('Glosario'), _t(' — define un término con '), _c('término:definición'), _t('. El término aparece como título.')]),
        _p([_b('Credencial'), _t(' — almacena contraseñas con '), _c('servicio*user*pass'), _t('. Solo visible con la '), _b('Contraseña Maestra'), _t(' desbloqueada.')]),
        _p([
          _i('Nota: '),
          _t('las credenciales se crean exclusivamente desde la barra de entrada rápida.'),
        ]),
      ],
    ),

    // ── 3. Etiquetas ──
    _ManualSection(
      title: 'Etiquetas',
      icon: Icons.label_outline,
      paragraphs: [
        _p([_t('Las etiquetas ('), _c('tags'), _t(') te permiten clasificar y filtrar entradas.')]),
        _p([_b('Crear'), _t(': desde "Gestionar etiquetas" en Ajustes o escribiendo '), _c('-#tag'), _t(' en la entrada rápida.')]),
        _p([_b('Colores'), _t(': cada etiqueta puede tener un color asignado. Se muestra como un badge en las tarjetas.')]),
        _p([_b('Etiquetas seguras'), _t(': marcá una etiqueta como '), _c('segura'), _t('. Las entradas con etiquetas seguras solo se muestran cuando la '), _b('Contraseña Maestra'), _t(' está desbloqueada.')]),
        _p([_b('Autocompletado'), _t(': al escribir '), _c('-#'), _t(' en la entrada rápida, Taúl sugiere etiquetas existentes.')]),
        _p([
          _i('Consejo: '),
          _t('agregá etiquetas sobre la marcha con '),
          _c('-#tag'),
          _t(' al crear una entrada. Si la etiqueta no existe, se crea automáticamente.'),
        ]),
      ],
    ),

    // ── 4. Combinar entradas ──
    _ManualSection(
      title: 'Combinar entradas',
      icon: Icons.merge_type,
      paragraphs: [
        _p([_t('Seleccioná dos o más entradas desde la pantalla principal (modo selección) y combinalas en una sola.')]),
        _p([_b('Comportamiento'), _t(': el contenido de todas las entradas se concatena. Las etiquetas se fusionan. El resultado es una entrada de tipo '), _b('Nota'), _t('.')]),
        _p([_b('⚠️ Advertencia'), _t(': esta operación es '), _b('destructiva'), _t('. Las entradas originales se eliminan y '), _b('no se puede deshacer'), _t('. Asegurate de seleccionar las correctas antes de confirmar.')]),
      ],
    ),

    // ── 5. Contraseña Maestra ──
    _ManualSection(
      title: 'Contraseña Maestra',
      icon: Icons.lock_outline,
      paragraphs: [
        _p([_b('¿Qué es?'), _t(' — es la clave que protege tus credenciales y etiquetas seguras. Sin ella, esos datos no se pueden leer.')]),
        _p([_b('Configuración'), _t(': desde Ajustes → "Configurar Contraseña Maestra". Establecé una contraseña y guardá los '), _b('códigos de respaldo'), _t(' en un lugar seguro.')]),
        _p([_b('Cambio'), _t(': desde Ajustes → "Cambiar Contraseña Maestra". Necesitás la contraseña actual.')]),
        _p([_b('Códigos de respaldo'), _t(': se generan al configurar. Usalos si olvidás tu contraseña. Cada código solo se puede usar una vez. Regeneralos desde Ajustes.')]),
        _p([_b('Seguridad'), _t(': las credenciales se cifran con '), _c('AES-256-GCM'), _t(' y la clave se deriva con '), _c('Argon2id'), _t('. Mientras la bóveda está bloqueada, las credenciales y etiquetas seguras permanecen ocultas.')]),
      ],
    ),

    // ── 6. Atajos de teclado ──
    _ManualSection(
      title: 'Atajos de teclado',
      icon: Icons.keyboard,
      paragraphs: [
        _p([_b('Ctrl + N'), _t(' — nueva entrada (solo en pantalla principal)')]),
        _p([_b('Ctrl + F'), _t(' — enfocar el campo de búsqueda (pantalla principal)')]),
        _p([_b('Ctrl + ,'), _t(' — ir a Configuración')]),
        _p([_b('Ctrl + Shift + T'), _t(' — ir a Papelera')]),
        _p([_b('Esc'), _t(' — volver a la pantalla principal desde cualquier sección')]),
        _p([_i('Nota: '), _t('los atajos funcionan con '), _b('Ctrl'), _t(' en Windows/Linux.')]),
      ],
    ),

    // ── 7. Configuración ──
    _ManualSection(
      title: 'Configuración',
      icon: Icons.settings,
      paragraphs: [
        _p([_b('Contraseña Maestra'), _t(': configurar, cambiar, editar pista, regenerar códigos de respaldo, eliminar protección.')]),
        _p([_b('Seguridad'), _t(': activar bloqueo general al iniciar la app, configurar bloqueo automático por inactividad (1, 5, 15, 30 minutos).')]),
        _p([_b('Tema'), _t(': elegir entre tema claro, oscuro o seguir el del sistema.')]),
        _p([_b('Datos'), _t(': exportar todas las entradas a JSON o importar desde un archivo. Las importaciones agregan entradas nuevas sin sobrescribir existentes.')]),
        _p([_b('Etiquetas'), _t(': crear, editar nombre, asignar color, marcar como segura o eliminar etiquetas.')]),
        _p([_b('Zona de Peligro'), _t(': eliminar la Contraseña Maestra. Esto '), _b('descifra y destruye permanentemente'), _t(' todas las credenciales y etiquetas seguras. '), _b('No se puede deshacer'), _t('.')]),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual de usuario'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          for (final section in _sections) _buildSection(context, section),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, _ManualSection section) {
    return ExpansionTile(
      leading: Icon(section.icon),
      title: Text(
        section.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in section.paragraphs) ...[
                if (p is _TextParagraph)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SelectableText.rich(
                      p.span,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (p is _BulletParagraph)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Expanded(
                          child: SelectableText.rich(
                            p.span,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
