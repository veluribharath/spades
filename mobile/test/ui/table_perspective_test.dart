import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/ui/table_perspective.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

void main() {
  test('every player sees themselves at the bottom, in turn order', () {
    final session = GameSession(
      players: {
        Seat.south: const SessionPlayer.human('Ann'),
        Seat.west: const SessionPlayer.human('Bea'),
        Seat.north: const SessionPlayer.human('Cal'),
        Seat.east: const SessionPlayer.human('Dev'),
      },
      random: Random(1),
    );
    for (final me in Seat.values) {
      final p = TablePerspective(session.viewFor(me));
      expect(p.toScreen(me), Seat.south);
      expect(p.toScreen(me.partner), Seat.north);
      // Play goes clockwise: the next player is on your left.
      expect(p.toScreen(me.next), Seat.west);
      for (final s in Seat.values) {
        expect(p.fromScreen(p.toScreen(s)), s);
      }
    }
    final bea = TablePerspective(session.viewFor(Seat.west));
    expect(bea.usLabel, 'You & Dev');
    expect(bea.themLabel, 'Cal & Ann');
    session.dispose();
  });
}
