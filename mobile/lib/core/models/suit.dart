/// The four suits. Spades are always trump per docs/RULES.md §1.
enum Suit {
  clubs,
  diamonds,
  spades,
  hearts;

  String get symbol => switch (this) {
    Suit.spades => '♠',
    Suit.hearts => '♥',
    Suit.diamonds => '♦',
    Suit.clubs => '♣',
  };

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}
