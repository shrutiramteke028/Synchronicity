import 'package:flutter_test/flutter_test.dart';
import 'package:synchronicity/main.dart';

void main() {
  testWidgets('Synchronicity app renders onboarding header smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SynchronicityApp());
    expect(find.text('SYNCHRONICITY'), findsOneWidget);
  });
}
