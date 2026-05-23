import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class TaulSearchBar extends ConsumerStatefulWidget {
  const TaulSearchBar({super.key});

  @override
  ConsumerState<TaulSearchBar> createState() => _TaulSearchBarState();
}

class _TaulSearchBarState extends ConsumerState<TaulSearchBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _isOpen = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isOpen = true);
    _animCtrl.forward();
  }

  void _close() {
    _controller.clear();
    ref.read(entrySearchProvider.notifier).state = '';
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _isOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: _isOpen ? _buildSearchInput() : _buildSearchIcon(),
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
    return SizeTransition(
      sizeFactor: _expandAnimation,
      axisAlignment: -1,
      child: TextField(
        controller: _controller,
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
