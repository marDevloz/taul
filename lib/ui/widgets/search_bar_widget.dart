import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class TaulSearchBar extends StatefulWidget {
  const TaulSearchBar({super.key});

  @override
  State<TaulSearchBar> createState() => _TaulSearchBarState();
}

class _TaulSearchBarState extends State<TaulSearchBar> {
  final _controller = TextEditingController();
  bool _isOpen = false;

  ProviderContainer get _container => ProviderScope.containerOf(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => setState(() => _isOpen = true);

  void _close() {
    _controller.clear();
    _container.read(entrySearchProvider.notifier).state = '';
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft,
        child: _isOpen ? _buildSearchInput() : _buildSearchIcon(),
      ),
    );
  }

  Widget _buildSearchIcon() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _open,
          tooltip: 'Buscar',
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _controller,
      autofocus: true,
      onChanged: (value) =>
          _container.read(entrySearchProvider.notifier).state = value,
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
    );
  }
}
