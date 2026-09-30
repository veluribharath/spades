import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _storageKey = 'spades.tabClientId';
const _channelName = 'spades-tab-ids';

Future<String?>? _resolved;

/// The id lives in sessionStorage (per tab, kept across reloads). A
/// duplicated tab inherits a copy of it, so before using it we ask the
/// other open tabs whether it's already taken, and pick a new one if so.
Future<String?> tabScopedId(String Function() generate) =>
    _resolved ??= _resolve(generate);

Future<String?> _resolve(String Function() generate) async {
  try {
    final storage = web.window.sessionStorage;
    var id = storage.getItem(_storageKey) ?? generate();
    // Breaks the tie when two tabs holding the same id load at the same
    // moment (e.g. a browser restoring a duplicated tab): the lower
    // nonce keeps the id, the other picks a new one.
    final nonce = generate();
    final channel = web.BroadcastChannel(_channelName);
    final taken = Completer<bool>();
    var confirmed = false;

    channel.onmessage = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! String) return;
      final parts = data.split(':');
      if (parts.length < 2 || parts[1] != id) return;
      if (parts[0] == 'ask' && parts.length == 3) {
        final theirs = parts[2];
        if (theirs == nonce) return; // our own message
        if (confirmed || nonce.compareTo(theirs) < 0) {
          channel.postMessage('have:$id'.toJS);
        } else if (!taken.isCompleted) {
          taken.complete(true);
        }
      } else if (parts[0] == 'have' && !confirmed && !taken.isCompleted) {
        taken.complete(true);
      }
    }).toJS;

    channel.postMessage('ask:$id:$nonce'.toJS);
    final duplicate = await taken.future.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () => false,
    );
    if (duplicate) id = generate();
    confirmed = true;
    storage.setItem(_storageKey, id);
    // The channel stays open for the life of the tab, answering for [id].
    return id;
  } catch (_) {
    return null;
  }
}
