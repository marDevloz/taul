import 'package:flutter/material.dart';
import 'package:taul/core/auto_updater.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        children: [
          // ── Icon ──
          Icon(
            Icons.lock_outline,
            size: 72,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),

          // ── Name ──
          Text(
            'Taúl',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // ── Version ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'v$appVersion',
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Description ──
          Text(
            'Taúl es un vault personal offline-first con cifrado de extremo a extremo. '
            'Almacená notas, credenciales y más con la tranquilidad de que tus datos '
            'están protegidos antes de llegar al disco.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Info card ──
          Card(
            child: Column(
              children: [
                _infoTile(
                  context,
                  icon: Icons.person_outline,
                  label: 'Creado por',
                  value: 'MarDevloz',
                ),
                const Divider(height: 1),
                _infoTile(
                  context,
                  icon: Icons.code_outlined,
                  label: 'Framework',
                  value: 'Flutter 3.44 — Dart 3.12',
                ),
                const Divider(height: 1),
                _infoTile(
                  context,
                  icon: Icons.storage_outlined,
                  label: 'Base de datos',
                  value: 'SQLite (Drift)',
                ),
                const Divider(height: 1),
                _infoTile(
                  context,
                  icon: Icons.security_outlined,
                  label: 'Cifrado',
                  value: 'AES-256-GCM — Argon2id',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Footer ──
          Text(
            'Hecho con ❤️ para quien valora su privacidad.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
