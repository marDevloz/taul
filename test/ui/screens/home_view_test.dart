import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/ui/screens/home_view.dart';

void main() {
  testWidgets('should_render_home_view_with_title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeView())),
    );

    expect(find.text('Taúl'), findsOneWidget);
  });

  testWidgets('should_show_empty_state_message', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeView())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No entries yet. Tap + to create one.'), findsOneWidget);
  });

  testWidgets('should_have_add_button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeView())),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
