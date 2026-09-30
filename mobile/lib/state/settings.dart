import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// What the app remembers between launches for multiplayer: your name,
/// the last address you joined, and a stable client id so a restarted
/// app can reclaim its seat in a running game.
class MultiplayerSettings {
  MultiplayerSettings._(this._prefs);

  static Future<MultiplayerSettings> load() async =>
      MultiplayerSettings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _nameKey = 'mp.name';
  static const _addressKey = 'mp.address';
  static const _clientIdKey = 'mp.clientId';
  static const _lastRoomKey = 'mp.lastRoom';

  String get name => _prefs.getString(_nameKey) ?? '';
  set name(String value) => _prefs.setString(_nameKey, value.trim());

  String get address => _prefs.getString(_addressKey) ?? '';
  set address(String value) => _prefs.setString(_addressKey, value.trim());

  /// The last room code joined, offered back after a restart.
  String get lastRoom => _prefs.getString(_lastRoomKey) ?? '';
  set lastRoom(String value) => _prefs.setString(_lastRoomKey, value);

  String get clientId {
    final existing = _prefs.getString(_clientIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = String.fromCharCodes([
      for (var i = 0; i < 20; i++)
        chars.codeUnitAt(random.nextInt(chars.length)),
    ]);
    _prefs.setString(_clientIdKey, id);
    return id;
  }
}
