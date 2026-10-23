import 'package:flutter_test/flutter_test.dart';
import 'package:dinor/main.dart';

void main() {
  testWidgets('Dinor app renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const DinorApp());
    expect(find.text('Dinor'), findsOneWidget);
  });
}
