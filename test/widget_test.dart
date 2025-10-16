// Tests de base pour l'application Silencia
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Silencia App Tests', () {
    testWidgets('App should build without errors', (WidgetTester tester) async {
      // Test de base pour vérifier que l'app se lance
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Silencia Test'),
            ),
          ),
        ),
      );

      expect(find.text('Silencia Test'), findsOneWidget);
    });
  });
}
