import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidflow/app.dart';

void main() {
  testWidgets('Vidflow app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VidflowApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vidflow'), findsOneWidget);
    expect(find.text('Generate Video'), findsOneWidget);
  });
}
