/// The four seats around the table, fixed clockwise order, human at South
/// per docs/RULES.md §8.
enum Seat {
  south,
  west,
  north,
  east;

  Seat get next => Seat.values[(index + 1) % Seat.values.length];

  /// The two fixed partnerships: South/North vs West/East.
  Team get team => (this == Seat.south || this == Seat.north)
      ? Team.southNorth
      : Team.westEast;

  Seat get partner => switch (this) {
    Seat.south => Seat.north,
    Seat.north => Seat.south,
    Seat.west => Seat.east,
    Seat.east => Seat.west,
  };
}

enum Team {
  southNorth,
  westEast;

  Team get opponent =>
      this == Team.southNorth ? Team.westEast : Team.southNorth;

  List<Seat> get seats => this == Team.southNorth
      ? [Seat.south, Seat.north]
      : [Seat.west, Seat.east];
}
