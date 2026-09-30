import 'card.dart';
import 'seat.dart';
import 'suit.dart';

/// One trick in progress or completed: an ordered record of which seat
/// played which card, starting with [leader].
class Trick {
  Trick({required this.leader}) : plays = [];

  final Seat leader;
  final List<MapEntry<Seat, PlayingCard>> plays;

  bool get isComplete => plays.length == Seat.values.length;

  Suit? get leadSuit => plays.isEmpty ? null : plays.first.value.suit;

  Seat get nextToPlay => plays.isEmpty ? leader : plays.last.key.next;

  void play(Seat seat, PlayingCard card) {
    assert(!isComplete, 'Trick already has 4 plays');
    assert(seat == nextToPlay, 'Cards must be played in seat order');
    plays.add(MapEntry(seat, card));
  }
}
