import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spades_app/app.dart';
import 'package:spades_app/state/remote_table_client.dart';
import 'package:spades_app/ui/screens/multiplayer_screen.dart';
import 'package:spades_app/ui/screens/room_screen.dart';
import 'package:spades_app/ui/screens/table_screen.dart';
import 'package:spades_engine/multiplayer.dart';

import 'support/in_memory_hub.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home screen offers single-player and multiplayer', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SpadesApp()));

    expect(find.text('Spades'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Play with friends'), findsOneWidget);
  });

  testWidgets('tapping New game opens the table screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpadesApp()));

    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();

    expect(find.byType(TableScreen), findsOneWidget);
    expect(find.text('You & North'.toUpperCase()), findsOneWidget);
  });

  testWidgets('Play with friends opens the multiplayer screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpadesApp()));

    await tester.tap(find.text('Play with friends'));
    await tester.pumpAndSettle();

    expect(find.byType(MultiplayerScreen), findsOneWidget);
    expect(find.text('Create room'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Join room'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Join room'), findsOneWidget);
  });

  testWidgets('a room shows its code and seats, then the table', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final hub = RoomHub(
        random: Random(5),
        timing: const SessionTiming.instant(),
      );
      final net = InMemoryHub(hub);
      final client = RemoteTableClient(
        server: Uri.parse('ws://test:8080/'),
        name: 'Alice',
        clientId: 'alice-widget',
        connect: net.connect,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RoomScreen(client: client, serverLabel: 'test'),
        ),
      );
      while (client.room == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await tester.pump();
      final code = client.room!.code;
      expect(find.text(code.split('').join(' ')), findsOneWidget);
      expect(find.text('Alice (you)'), findsOneWidget);
      expect(find.text('Open seat'), findsNWidgets(3));
      expect(find.text('Start with bots'), findsOneWidget);

      await tester.tap(find.text('Start with bots'));
      while (client.view == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await tester.pump();
      expect(find.byType(TableScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      hub.dispose();
    });
  });
}
