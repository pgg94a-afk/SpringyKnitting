import 'package:flutter_test/flutter_test.dart';
import 'package:springy_knitting/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SpringyKnitApp());

    expect(find.text('SpringyKnit'), findsOneWidget);
    expect(find.text('뜨개리포트'), findsOneWidget);
  });
}
