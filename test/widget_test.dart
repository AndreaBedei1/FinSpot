// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seawatch/main.dart';
import 'package:seawatch/services/ManagementTheme/ThemeProvider.dart';

void main() {
  testWidgets('MyApp shows login screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(isAuthenticated: false),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Accedi'), findsWidgets);
  });
}
