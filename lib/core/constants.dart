import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const String appName = 'Taúl';
  static const String databaseName = 'taul.db';
  static const int fts5MaxResults = 100;
  static const int staleBackupReminderDays = 14;
  static const int maxTitleLength = 255;
  static const int maxContentLength = 100000;
}

class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
}

extension ResponsiveBreakpoints on BuildContext {
  bool get isNarrow => MediaQuery.of(this).size.width < Breakpoints.mobile;
  bool get isMedium =>
      MediaQuery.of(this).size.width >= Breakpoints.mobile &&
      MediaQuery.of(this).size.width < Breakpoints.tablet;
  bool get isWide => MediaQuery.of(this).size.width >= Breakpoints.tablet;
}
