import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:taul/app.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop tray — async init before app starts
  if (Platform.isWindows) {
    _initDesktopTray().whenComplete(() {
      runApp(const ProviderScope(child: TaulApp()));
    });
  } else {
    runApp(const ProviderScope(child: TaulApp()));
  }
}

/// Desktop tray setup. Gracefully falls back if tray isn't available.
Future<void> _initDesktopTray() async {
  try {
    await windowManager.ensureInitialized();
    await _initSystemTray();
  } catch (e) {
    // System tray no disponible — la app funciona igual
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

void _exitApp() {
  exit(0);
}
