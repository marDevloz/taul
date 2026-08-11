import 'dart:io' show Platform, exit;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:taul/app.dart';
import 'package:taul/core/quick_capture_bus.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  // Drift warns about multiple AppDatabase instances during DEK rotation.
  // Our _DatabaseManager ensures only one live instance at a time, but
  // close() is async so the count briefly exceeds 1 in debug builds.
  // This is safe — no queries run on the old instance after DEK change.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  print('[DRIFT] dontWarnAboutMultipleDatabases = ${driftRuntimeOptions.dontWarnAboutMultipleDatabases}');

  WidgetsFlutterBinding.ensureInitialized();

  // Desktop tray — async init before app starts
  if (Platform.isWindows) {
    _initDesktopTray().whenComplete(() {
      runApp(const ProviderScope(child: _WindowApp()));
    });
  } else {
    runApp(const ProviderScope(child: TaulApp()));
  }
}

/// Wrapper que escucha el cierre de ventana y sale realmente.
class _WindowApp extends StatefulWidget {
  const _WindowApp();

  @override
  State<_WindowApp> createState() => _WindowAppState();
}

class _WindowAppState extends State<_WindowApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.destroy();
    exit(0);
  }

  @override
  Widget build(BuildContext context) => const TaulApp();
}

/// Desktop tray + global hotkey setup. Gracefully falls back if unavailable.
Future<void> _initDesktopTray() async {
  try {
    await windowManager.ensureInitialized();
    await _initSystemTray();
  } catch (_) {
    // System tray no disponible — la app funciona igual
  }
  await _initGlobalHotkey();
}

/// Global hotkey for instant quick capture (Ctrl+Alt+N). Fires the shared
/// [QuickCaptureBus] so HomeView opens the create form from anywhere.
Future<void> _initGlobalHotkey() async {
  try {
    await hotKeyManager.unregisterAll();
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyN,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system, // system-wide = global hotkey
      ),
      keyDownHandler: (_) => QuickCaptureBus.trigger(),
    );
  } catch (_) {
    // Hotkey no disponible — la app funciona igual
  }
}

// ---------------------------------------------------------------------------
// System tray
// ---------------------------------------------------------------------------

Future<void> _initSystemTray() async {
  final tray = SystemTray();

  await tray.initSystemTray(
    title: 'Taúl',
    iconPath: 'assets/images/icon.png',
    toolTip: 'Taúl',
  );

  await tray.setContextMenu([
    MenuItem(
      label: 'Abrir Taúl',
      onClicked: _showWindow,
    ),
    MenuItem(
      label: 'Captura rápida',
      onClicked: _quickCaptureFromTray,
    ),
    MenuItem(
      label: 'Salir',
      onClicked: _exitApp,
    ),
  ]);

  // Left-click on tray icon → show window
  tray.registerSystemTrayEventHandler((eventName) {
    if (eventName == 'leftMouseUp') {
      _showWindow();
    }
  });
}

// ---------------------------------------------------------------------------
// Window helpers
// ---------------------------------------------------------------------------

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

/// Shows the window and fires quick capture. The listener only opens the
/// create form when HomeView is mounted, so a window that is still focusing
/// retries safely.
void _quickCaptureFromTray() {
  _showWindow();
  QuickCaptureBus.trigger();
}

void _exitApp() {
  exit(0);
}
