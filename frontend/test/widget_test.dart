import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindvault/app/mind_vault_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows graph-first home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MindVaultApp()));
    await tester.pumpAndSettle();

    expect(find.text('MindVault'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
