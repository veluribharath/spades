import 'tab_identity_stub.dart'
    if (dart.library.js_interop) 'tab_identity_web.dart'
    as impl;

/// In the browser every tab shares saved preferences, so two tabs would
/// look like the same player (and the second would take over the first
/// one's seat). This resolves to an id unique to the current tab that
/// survives reloads, or null on platforms where it isn't needed.
Future<String?> tabScopedId(String Function() generate) =>
    impl.tabScopedId(generate);
