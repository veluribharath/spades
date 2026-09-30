import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

/// Draws the table from one player's chair: whoever the [view] belongs
/// to sits at the bottom (screen South), the player after them in turn
/// order on the left (screen West), their partner across (screen North).
class TablePerspective {
  const TablePerspective(this.view);

  final TableView view;

  Seat get me => view.seat;

  /// Where an absolute [seat] is drawn.
  Seat toScreen(Seat seat) =>
      Seat.values[(seat.index - me.index + Seat.values.length) %
          Seat.values.length];

  /// Which absolute seat is drawn at [screenSeat].
  Seat fromScreen(Seat screenSeat) =>
      Seat.values[(screenSeat.index + me.index) % Seat.values.length];

  String name(Seat seat) => seat == me ? 'You' : view.info(seat).name;

  Team get us => me.team;
  Team get them => me.team.opponent;

  String get usLabel => 'You & ${name(me.partner)}';

  String get themLabel =>
      '${name(fromScreen(Seat.west))} & ${name(fromScreen(Seat.east))}';

  String teamLabel(Team team) => team == us ? usLabel : themLabel;
}
