import 'package:flutter_test/flutter_test.dart';
import 'package:publicaid/app.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PublicaidApp());
    expect(find.text('Publicaid'), findsOneWidget);
  });
}
