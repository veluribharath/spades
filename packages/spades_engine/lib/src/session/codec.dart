import '../models/bid.dart';
import '../models/card.dart';
import '../models/match_config.dart';
import '../models/rank.dart';
import '../models/seat.dart';
import '../models/suit.dart';

/// Thrown when a message or view field can't be decoded. Everything that
/// arrives over the wire goes through these decoders, so malformed input
/// surfaces as this one exception type rather than a random TypeError.
class DecodeException implements Exception {
  DecodeException(this.message);
  final String message;

  @override
  String toString() => 'DecodeException: $message';
}

const _suitLetters = {
  Suit.clubs: 'C',
  Suit.diamonds: 'D',
  Suit.spades: 'S',
  Suit.hearts: 'H',
};

/// Cards travel as short codes: rank label + suit letter ("10H", "AS").
String encodeCard(PlayingCard card) =>
    '${card.rank.label}${_suitLetters[card.suit]}';

PlayingCard decodeCard(Object? code) {
  if (code is! String || code.length < 2 || code.length > 3) {
    throw DecodeException('Bad card: $code');
  }
  final letter = code.substring(code.length - 1);
  final label = code.substring(0, code.length - 1);
  final suit = _suitLetters.entries
      .where((e) => e.value == letter)
      .firstOrNull
      ?.key;
  final rank = Rank.values.where((r) => r.label == label).firstOrNull;
  if (suit == null || rank == null) throw DecodeException('Bad card: $code');
  return PlayingCard(suit, rank);
}

/// Bids travel as "0".."13", "nil" or "blindNil".
String encodeBid(Bid bid) {
  if (bid.isBlind) return 'blindNil';
  if (bid.isNil) return 'nil';
  return '${bid.tricks}';
}

Bid decodeBid(Object? code) {
  if (code == 'nil') return Bid.nil();
  if (code == 'blindNil') return Bid.blindNil();
  final tricks = code is String ? int.tryParse(code) : null;
  if (tricks == null || tricks < 0 || tricks > 13) {
    throw DecodeException('Bad bid: $code');
  }
  return Bid.regular(tricks);
}

Seat decodeSeat(Object? name) => _decodeEnum(Seat.values, name, 'seat');

Team decodeTeam(Object? name) => _decodeEnum(Team.values, name, 'team');

T decodeEnumValue<T extends Enum>(List<T> values, Object? name, String what) =>
    _decodeEnum(values, name, what);

T _decodeEnum<T extends Enum>(List<T> values, Object? name, String what) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw DecodeException('Bad $what: $name');
}

Map<String, Object?> encodeConfig(MatchConfig c) => {
  'targetScore': c.targetScore,
  'lossFloor': c.lossFloor,
  'nilEnabled': c.nilEnabled,
  'blindNilEnabled': c.blindNilEnabled,
  'bostonBonusEnabled': c.bostonBonusEnabled,
  'bagPenaltyEvery': c.bagPenaltyEvery,
  'bagPenaltyAmount': c.bagPenaltyAmount,
  'progressiveDealing': c.progressiveDealing,
};

MatchConfig decodeConfig(Object? json) {
  final m = asMap(json, 'config');
  return MatchConfig(
    targetScore: readInt(m, 'targetScore'),
    lossFloor: readInt(m, 'lossFloor'),
    nilEnabled: readBool(m, 'nilEnabled'),
    blindNilEnabled: readBool(m, 'blindNilEnabled'),
    bostonBonusEnabled: readBool(m, 'bostonBonusEnabled'),
    bagPenaltyEvery: readInt(m, 'bagPenaltyEvery'),
    bagPenaltyAmount: readInt(m, 'bagPenaltyAmount'),
    progressiveDealing: readBool(m, 'progressiveDealing'),
  );
}

// -- small typed readers for decoded JSON ---------------------------------

Map<String, Object?> asMap(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  if (json is Map) return json.cast<String, Object?>();
  throw DecodeException('Expected an object for $what');
}

List<Object?> asList(Object? json, String what) {
  if (json is List) return json.cast<Object?>();
  throw DecodeException('Expected a list for $what');
}

int readInt(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is int) return v;
  throw DecodeException('Expected an int for $key');
}

bool readBool(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is bool) return v;
  throw DecodeException('Expected a bool for $key');
}

String readString(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is String) return v;
  throw DecodeException('Expected a string for $key');
}
