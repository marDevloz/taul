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
sealed class _Paragraph {
  const _Paragraph();
}

final class _TextParagraph extends _Paragraph {
  final TextSpan span;
  const _TextParagraph(this.span);
}

final class _BulletParagraph extends _Paragraph {
  final TextSpan span;
  const _BulletParagraph(this.span);
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
    // ── 1. Tipos de entrada ──
    _ManualSection(
      title: 'Tipos de entrada',
      icon: Icons.category_outlined,
      paragraphs: [
        _p([_b('Nota'), _t(' — tipo predeterminado. Sin prefijo especial. Texto libre con formato enriquecido (negrita, cursiva). Icono: '), _c('description'), _t('.')]),
        _p([_b('Idea'), _t(' — comienza con '), _c('!'), _t(' sin espacio después (ej: '), _c('!idea genial'), _t('). El '), _c('!'), _t(' se elimina del contenido al guardar. Icono: '), _c('lightbulb'), _t('.')]),
        _p([_b('Glosario'), _t(' — usa el formato '), _c('término:definición'), _t(' sin espacios alrededor de los dos puntos (ej: '), _c('Flutter:framework de Google'), _t('). El término se muestra en negrita y la definición en cursiva. Icono: '), _c('book'), _t('.')]),
        _p([_b('Credencial'), _t(' — usa el formato '), _c('servicio*user*pass'), _t(' con el caracter '), _c('*'), _t(' rodeado de texto (ej: '), _c('github*manu*pass123'), _t('). Solo visible con la Contraseña Maestra desbloqueada. Icono: '), _c('lock'), _t('.')]),
        _p([_b('Tarea'), _t(' — tipo manual, se asigna desde el selector de tipo. Agrega automáticamente la etiqueta '), _c('pendiente'), _t(' al crear. Ideal para seguimiento de acciones pendientes. Icono: '), _c('checklist'), _t('.')]),
        _p([_i('Consejo: '), _t('si necesitás usar '), _c('!'), _t(', '), _c('*'), _t(' o '), _c(':'), _t(' en una nota normal, dejá un espacio después del carácter y Taúl lo tratará como texto común sin detectar un tipo especial.')]),
      ],
    ),

    // ── 2. Sintaxis de agregado rápido ──
    _ManualSection(
      title: 'Sintaxis de agregado rápido',
      icon: Icons.bolt,
      paragraphs: [
        _p([_t('La ventana de agregado rápido (') , _b('Ctrl+N'), _t(') permite crear entradas escribiendo todo en una línea. Taúl detecta automáticamente el tipo y extrae etiquetas.')]),
        _p([_b('Prefijos de tipo')]),
        _bp([_c('!texto'), _t(' → '), _b('Idea'), _t('. El texto después de '), _c('!'), _t(' sin espacio se guarda como contenido de tipo Idea.')]),
        _bp([_c('servicio*user*pass'), _t(' → '), _b('Credencial'), _t('. El patrón con '), _c('*'), _t(' rodeado de texto activa el tipo Credencial.')]),
        _bp([_c('término:definición'), _t(' → '), _b('Glosario'), _t('. Los dos puntos sin espacio antes detectan el tipo Glosario.')]),
        _bp([_c('Título# texto'), _t(' → '), _b('Nota con título explícito'), _t('. El texto antes de '), _c('# '), _t(' (almohadilla seguida de espacio) se usa como título.')]),
        _p([_b('Inyección de etiquetas')]),
        _bp([_c('-#etiqueta'), _t(' → agrega una etiqueta a la entrada. El formato exacto es '), _c('-#'), _t(' seguido del nombre de la etiqueta. Podés agregar varias: '), _c('-#libros -#pendiente'), _t('.')]),
        _p([_i('Consejo: '), _t('las etiquetas se extraen automáticamente del texto y no forman parte del contenido guardado.')]),
      ],
    ),

    // ── 3. Referencia de etiquetas ──
    _ManualSection(
      title: 'Referencia de etiquetas',
      icon: Icons.label_outline,
      paragraphs: [
        _p([_t('Las etiquetas ('), _c('tags'), _t(') clasifican y filtran entradas. Se crean desde "Gestionar etiquetas" en Ajustes o sobre la marcha con '), _c('-#tag'), _t(' en el contenido.')]),
        _p([_b('Colores'), _t(': cada etiqueta tiene un color asignado, visible como badge en las tarjetas. Para cambiarlo, mantené presionada la etiqueta en cualquier entrada y elegí un color de la paleta. El cambio se aplica a todas las entradas con esa etiqueta.')]),
        _p([_b('Etiquetas seguras'), _t(': desde Gestión de etiquetas podés marcar una etiqueta como "segura". Las entradas con etiquetas seguras solo se muestran cuando la '), _b('Contraseña Maestra'), _t(' está desbloqueada. Esto permite ocultar contenido sensible junto con las credenciales.')]),
        _p([_b('Autocompletado'), _t(': al escribir etiquetas en el formulario de creación o edición, Taúl sugiere etiquetas existentes a medida que escribís, filtrando por coincidencia parcial.')]),
        _p([_b('Etiquetas de sistema'), _t(': algunas etiquetas son generadas automáticamente (como '), _c('pendiente'), _t(' para las tareas). Se muestran con un ícono de candado y no pueden renombrarse ni eliminarse.')]),
      ],
    ),

    // ── 4. Combinar entradas ──
    _ManualSection(
      title: 'Combinar entradas',
      icon: Icons.merge_type,
      paragraphs: [
        _p([_t('Seleccioná dos o más entradas desde la pantalla principal activando el modo selección y tocad el botón de combinación en la barra inferior.')]),
        _p([_b('Comportamiento'), _t(': el contenido de todas las entradas se concatena con separadores ("-- título --"). Las etiquetas de todas las entradas se fusionan en una sola lista única. El resultado es una entrada de tipo '), _b('Nota'), _t('.')]),
        _p([_b('Límite'), _t(': se pueden combinar hasta '), _b('20 entradas'), _t(' a la vez.')]),
        _p([_b('⚠️ Destructiva'), _t(': esta operación es '), _b('irreversible'), _t('. Las entradas originales '), _b('se eliminan permanentemente'), _t(' y '), _b('no se pueden recuperar'), _t(' (ni siquiera desde la papelera). Asegurate de seleccionar las entradas correctas antes de confirmar.')]),
      ],
    ),

    // ── 5. Protección de credenciales ──
    _ManualSection(
      title: 'Protección de credenciales',
      icon: Icons.lock_outline,
      paragraphs: [
        _p([_b('Contraseña Maestra'), _t(' — es la clave que protege tus credenciales y etiquetas seguras. Sin ella, esos datos no se pueden leer. Se configura desde Ajustes → "Configurar Contraseña Maestra".')]),
        _p([_b('Cifrado'), _t(': las credenciales se cifran con '), _c('AES-256-GCM'), _t(' y la clave de cifrado se deriva usando '), _c('Argon2id'), _t('. Esto asegura que los datos protegidos no puedan leerse sin la contraseña correcta.')]),
        _p([_b('Cierre de bóveda'), _t(': mientras la bóveda está bloqueada, las entradas de tipo Credencial y aquellas con etiquetas seguras '), _b('permanecen ocultas'), _t('. No aparecen en la lista principal ni en resultados de búsqueda.')]),
        _p([_b('Bloqueo automático'), _t(': podés configurar el bloqueo automático por inactividad desde Ajustes. Opciones: 1, 5, 15, 30 minutos o nunca. También podés activar el bloqueo al iniciar la app.')]),
        _p([_b('Códigos de respaldo'), _t(': se generan al configurar la Contraseña Maestra. Usalos si olvidás tu contraseña. Cada código solo se puede usar una vez. Podés regenerarlos desde Ajustes.')]),
        _p([_b('Pista'), _t(': podés asociar una pista a tu Contraseña Maestra para recordarla más fácilmente. Se muestra en la pantalla de desbloqueo.')]),
      ],
    ),

    // ── 6. Atajos de teclado ──
    _ManualSection(
      title: 'Atajos de teclado',
      icon: Icons.keyboard,
      paragraphs: [
        _p([_b('Globales (en toda la app)')]),
        _bp([_b('Ctrl + N'), _t(' — nueva entrada (abre el diálogo de creación)')]),
        _bp([_b('Ctrl + F'), _t(' — enfocar la barra de búsqueda')]),
        _bp([_b('Ctrl + ,'), _t(' — ir a Configuración')]),
        _bp([_b('Ctrl + Shift + T'), _t(' — ir a Papelera')]),
        _bp([_b('Esc'), _t(' — volver atrás o cerrar el panel actual')]),
        _p([_b('En detalle de entrada')]),
        _bp([_b('Ctrl + E'), _t(' — editar la entrada actual')]),
        _bp([_b('Delete'), _t(' — mover la entrada a la papelera')]),
        _bp([_b('Ctrl + ← / →'), _t(' — entrada anterior / siguiente')]),
        _bp([_b('Ctrl + Tab / Shift + Tab'), _t(' — entrada siguiente / anterior')]),
        _p([
          _i('Nota: '),
          _t('todos los atajos usan '),
          _b('Ctrl'),
          _t(' en Windows/Linux.'),
        ]),
      ],
    ),

    // ── 7. Resumen de configuración ──
    _ManualSection(
      title: 'Resumen de configuración',
      icon: Icons.settings,
      paragraphs: [
        _p([_b('Contraseña Maestra'), _t(': '), _i('Configurar'), _t(' — establece la contraseña y genera códigos de respaldo. '), _i('Cambiar'), _t(' — requiere la contraseña actual. '), _i('Editar Pista'), _t(' — asociá una pista visual. '), _i('Regenerar Códigos'), _t(' — invalida los códigos anteriores.')]),
        _p([_b('Seguridad'), _t(': '), _i('Bloqueo general'), _t(' — pide contraseña al iniciar la app. '), _i('Bloqueo automático'), _t(' — bloquea tras inactividad (1, 5, 15, 30 min o nunca).')]),
        _p([_b('Tema'), _t(': elegí entre tema '), _i('Claro'), _t(', '), _i('Oscuro'), _t(' o '), _i('Sistema'), _t(' (sigue la configuración del SO).')]),
        _p([_b('Datos'), _t(': '), _i('Exportar'), _t(' — guarda todas las entradas como archivo JSON. '), _i('Importar'), _t(' — agrega entradas desde un archivo JSON sin sobrescribir las existentes.')]),
        _p([_b('Etiquetas'), _t(': crear, renombrar, asignar color, marcar como segura o eliminar etiquetas desde "Gestionar etiquetas".')]),
        _p([_b('Bandeja del sistema'), _t(' (Windows): al cerrar la ventana, Taúl se minimiza a la bandeja en lugar de cerrarse. Clic derecho para '), _i('Abrir'), _t(' o '), _i('Salir'), _t('.')]),
        _p([_b('⚠️ Zona de Peligro'), _t(': '), _b('Eliminar Contraseña Maestra'), _t(' — descifra y destruye permanentemente todas las credenciales y etiquetas seguras. '), _b('Esta acción no se puede deshacer'), _t('. Los datos protegidos se pierden para siempre.')]),
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
