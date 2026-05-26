import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:taul/app.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop tray (fire-and-forget — non-blocking for startup)
  if (Platform.isWindows) {
    _initDesktopTray();
  }

  runApp(const ProviderScope(child: TaulApp()));
}

/// Async desktop tray setup. Runs in background so main() stays sync.
Future<void> _initDesktopTray() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  _initSystemTray();
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

  // Close button intercepted by window_manager → hide to tray
  windowManager.addListener(_WindowListener());
}

// ---------------------------------------------------------------------------
// Window helpers
// ---------------------------------------------------------------------------

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

void _exitApp() {
  exit(0);
}

// ---------------------------------------------------------------------------
// Window event listener — intercept close → hide instead
// ---------------------------------------------------------------------------

class _WindowListener extends WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}
