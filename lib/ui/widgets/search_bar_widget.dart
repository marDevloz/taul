import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Search input que se muestra/oculta según [isSearchOpenProvider].
///
/// El icono de búsqueda está en [AppBar.actions]; cuando se toca,
/// [isSearchOpenProvider] se setea a `true` y este widget aparece.
class TaulSearchBar extends ConsumerStatefulWidget {
  const TaulSearchBar({super.key});

  @override
  ConsumerState<TaulSearchBar> createState() => _TaulSearchBarState();
}

class _TaulSearchBarState extends ConsumerState<TaulSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Si al montar ya hay query (ej. después de rebuild), mostra-lo.
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _focus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _close() {
    _controller.clear();
    ref.read(entrySearchProvider.notifier).state = '';
    ref.read(isSearchOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(isSearchOpenProvider);

    // Auto-focus cuando se abre desde el AppBar o Ctrl+F
    ref.listen<bool>(focusSearchProvider, (prev, next) {
      if (next) {
        ref.read(isSearchOpenProvider.notifier).state = true;
        _focus();
        ref.read(focusSearchProvider.notifier).state = false;
      }
    });

    // Sync controller con query externa (por si se cerró y re-abre)
    ref.listen<String>(entrySearchProvider, (prev, next) {
      if (next.isEmpty && isOpen) {
        _controller.clear();
      }
    });

    if (!isOpen) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: (value) =>
            ref.read(entrySearchProvider.notifier).state = value,
        decoration: InputDecoration(
          hintText: 'Buscar en Taúl...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _close,
            tooltip: 'Cerrar',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
