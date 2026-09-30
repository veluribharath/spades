import 'package:flutter_test/flutter_test.dart';
import 'package:spades_app/net/server_address.dart';

void main() {
  test('bare IPs and hosts get ws:// and the game port', () {
    expect(
      parseServerAddress('192.168.1.20').toString(),
      'ws://192.168.1.20:8080/',
    );
    expect(
      parseServerAddress(' 192.168.1.20:9000 ').toString(),
      'ws://192.168.1.20:9000/',
    );
    expect(
      parseServerAddress('spades.example.com').toString(),
      'ws://spades.example.com:8080/',
    );
  });

  test('explicit schemes are respected', () {
    expect(
      parseServerAddress('wss://spades.example.com').toString(),
      'wss://spades.example.com:443/',
    );
    expect(
      parseServerAddress('https://spades.example.com/game').toString(),
      'wss://spades.example.com:443/game',
    );
    expect(
      parseServerAddress('http://10.0.0.5:8080').toString(),
      'ws://10.0.0.5:8080/',
    );
  });

  test('nonsense is rejected', () {
    for (final bad in ['', '   ', 'ftp://x', 'a b', '://']) {
      expect(parseServerAddress(bad), isNull, reason: bad);
    }
  });

  test('addresses are shown the way you would type them', () {
    expect(displayAddress(parseServerAddress('10.0.0.5')!), '10.0.0.5');
    expect(
      displayAddress(parseServerAddress('10.0.0.5:9000')!),
      '10.0.0.5:9000',
    );
    expect(
      displayAddress(parseServerAddress('wss://spades.example.com')!),
      'wss://spades.example.com',
    );
    expect(
      displayAddress(parseServerAddress('wss://example.com/spades')!),
      'wss://example.com/spades',
    );
    expect(
      parseServerAddress(displayAddress(parseServerAddress('h:9/x')!)),
      parseServerAddress('h:9/x'),
    );
  });
}
