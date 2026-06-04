import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/ui/screens/user_manual_screen.dart';

void main() {
  group('UserManualScreen', () {
    Future<void> pumpManual(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserManualScreen(),
        ),
      );
    }

    testWidgets('should show title in AppBar', (tester) async {
      await pumpManual(tester);
      expect(find.text('Manual de usuario'), findsOneWidget);
    });

    testWidgets('should render all 7 section titles', (tester) async {
      await pumpManual(tester);

      expect(find.text('Tipos de entrada'), findsOneWidget);
      expect(find.text('Sintaxis de agregado rápido'), findsOneWidget);
      expect(find.text('Referencia de etiquetas'), findsOneWidget);
      expect(find.text('Combinar entradas'), findsOneWidget);
      expect(find.text('Protección de credenciales'), findsOneWidget);
      expect(find.text('Atajos de teclado'), findsOneWidget);
      expect(find.text('Resumen de configuración'), findsOneWidget);
    });

    testWidgets('should render section icons', (tester) async {
      await pumpManual(tester);

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
      expect(find.byIcon(Icons.merge_type), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    group('Entry Types section', () {
      testWidgets('should list all entry types when expanded', (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Tipos de entrada'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Nota'), findsWidgets);
        expect(find.textContaining('Idea'), findsWidgets);
        expect(find.textContaining('Glosario'), findsWidgets);
        expect(find.textContaining('Credencial'), findsWidgets);
        expect(find.textContaining('Tarea'), findsWidgets);
      });
    });

    group('Quick-Add Syntax section', () {
      testWidgets('should document -#tag syntax when expanded', (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Sintaxis de agregado rápido'));
        await tester.pumpAndSettle();

        expect(find.textContaining('-#etiqueta'), findsWidgets);
      });
    });

    group('Tags Reference section', () {
      testWidgets('should mention secure tags with vault unlock when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Referencia de etiquetas'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Contraseña Maestra'),
          findsWidgets,
        );
        expect(
          find.textContaining('desbloqueada'),
          findsWidgets,
        );
      });
    });

    group('Merge Entries section', () {
      testWidgets('should warn about destructive merge when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Combinar entradas'));
        await tester.pumpAndSettle();

        expect(find.textContaining('irreversible'), findsWidgets);
        expect(find.textContaining('eliminan permanentemente'), findsWidgets);
        expect(find.textContaining('20 entradas'), findsWidgets);
      });
    });

    group('Credential Protection section', () {
      testWidgets('should name encryption algorithms when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Protección de credenciales'));
        await tester.pumpAndSettle();

        expect(find.textContaining('AES-256-GCM'), findsWidgets);
        expect(find.textContaining('Argon2id'), findsWidgets);
      });

      testWidgets('should mention vault lock hiding entries when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Protección de credenciales'));
        await tester.pumpAndSettle();

        expect(find.textContaining('permanecen ocultas'), findsWidgets);
      });
    });

    group('Keyboard Shortcuts section', () {
      testWidgets('should list global and detail shortcuts when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Atajos de teclado'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Ctrl + N'), findsWidgets);
        expect(find.textContaining('Ctrl + F'), findsWidgets);
        expect(find.textContaining('Ctrl + ,'), findsWidgets);
        expect(find.textContaining('Ctrl + Shift + T'), findsWidgets);
        expect(find.textContaining('Ctrl + E'), findsWidgets);
        expect(find.textContaining('Ctrl + Tab'), findsWidgets);
      });
    });

    group('Settings Overview section', () {
      testWidgets('should warn about danger zone when expanded',
          (tester) async {
        await pumpManual(tester);

        await tester.tap(find.text('Resumen de configuración'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Zona de Peligro'), findsWidgets);
        expect(
          find.textContaining('Eliminar Contraseña Maestra'),
          findsWidgets,
        );
        expect(
          find.textContaining('no se puede deshacer'),
          findsWidgets,
        );
      });
    });

    testWidgets('should expand and collapse sections on tap', (tester) async {
      await pumpManual(tester);

      // Initially collapsed — content not visible
      expect(find.textContaining('Nota'), findsNothing);

      // Expand
      await tester.tap(find.text('Tipos de entrada'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nota'), findsWidgets);

      // Collapse
      await tester.tap(find.text('Tipos de entrada'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nota'), findsNothing);
    });
  });
}
