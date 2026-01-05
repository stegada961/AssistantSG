import 'package:flutter_test/flutter_test.dart';
import 'package:assistant_sg/main.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const AssistantSGApp());
    await tester.pump();
    expect(find.byType(AssistantSGApp), findsOneWidget);
  });
}
