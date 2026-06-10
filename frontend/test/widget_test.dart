import 'package:flutter_test/flutter_test.dart';
import 'package:mindvault/main.dart' as app;

void main() {
  testWidgets('shows graph-first home screen', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('MindVault'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
