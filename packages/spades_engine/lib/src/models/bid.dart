/// A single player's bid for a hand. Per docs/RULES.md §3:
/// - a regular bid is 0-13 tricks
/// - [isNil] means a bid of exactly 0 tricks, declared as Nil
/// - [isBlind] means the bid was made before looking at the hand (Blind Nil)
class Bid {
  const Bid({required this.tricks, this.isNil = false, this.isBlind = false})
    : assert(tricks >= 0 && tricks <= 13, 'Bid must be 0-13'),
      assert(!isNil || tricks == 0, 'Nil bids must declare 0 tricks'),
      assert(!isBlind || isNil, 'Blind bids must be Nil bids');

  factory Bid.regular(int tricks) => Bid(tricks: tricks);

  factory Bid.nil() => const Bid(tricks: 0, isNil: true);

  factory Bid.blindNil() => const Bid(tricks: 0, isNil: true, isBlind: true);

  final int tricks;
  final bool isNil;
  final bool isBlind;

  /// The number of tricks this bid contributes to the team's combined
  /// trick target (Nil bids contribute 0 — they're scored separately).
  int get teamTricks => isNil ? 0 : tricks;

  @override
  String toString() {
    if (isBlind) return 'Blind Nil';
    if (isNil) return 'Nil';
    return '$tricks';
  }
}
