import 'package:flutter_test/flutter_test.dart';
import 'package:controldeck/main.dart';

void main() {
  testWidgets('shows the ControlDeck sign-in screen when signed out', (tester) async {
    await tester.pumpWidget(const ControlDeckApp());
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign in to sync your app hub across devices.'), findsOneWidget);
  });
}
