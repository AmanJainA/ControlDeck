import 'package:flutter_test/flutter_test.dart';
import 'package:controldeck/main.dart';

void main() {
  testWidgets('shows secure setup guidance when ControlDeck auth is not configured',
      (tester) async {
    await tester.pumpWidget(const ControlDeckApp());

    expect(find.text('Set up secure sign-in'), findsOneWidget);
    expect(find.textContaining('Run with SUPABASE_URL'), findsOneWidget);
  });
}
