// Basic smoke test for EcoGrow app.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecogrow/main.dart';

void main() {
  testWidgets('App renders login page', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoGrowApp(isLoggedIn: false));

    // Verify the login page title appears.
    expect(find.text('EcoGrow'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
