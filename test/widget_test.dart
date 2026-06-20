import 'package:flutter_test/flutter_test.dart';
import 'package:envite_canario/main.dart';

void main() {
  testWidgets('App carga sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const EnviteApp());
    expect(find.byType(EnviteApp), findsOneWidget);
  });
}
