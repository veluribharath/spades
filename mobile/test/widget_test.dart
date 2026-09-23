import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spades_app/app.dart';
import 'package:spades_app/ui/screens/table_screen.dart';

void main() {
  testWidgets('home screen shows the New game button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpadesApp()));

    expect(find.text('Spades'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
  });

  testWidgets('tapping New game opens the table screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpadesApp()));

    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();

    expect(find.byType(TableScreen), findsOneWidget);
  });
}
