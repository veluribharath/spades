import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../net/local_host.dart';
import '../../net/server_address.dart';
import '../../state/remote_table_client.dart';
import '../../state/settings.dart';
import '../theme/app_theme.dart';
import '../widgets/score_history_dialog.dart';
import 'room_screen.dart';

enum _HostOn { thisDevice, server }

/// Host a room (on this phone or on a server) or join one by address and
/// room code.
class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key, this.connector});

  /// For tests: how clients reach the server.
  final ChannelConnector? connector;

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final _name = TextEditingController();
  final _hostServer = TextEditingController();
  final _joinAddress = TextEditingController();
  final _code = TextEditingController();
  MultiplayerSettings? _settings;
  _HostOn _hostOn = canHostOnThisDevice ? _HostOn.thisDevice : _HostOn.server;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    MultiplayerSettings.load().then((settings) {
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _name.text = settings.name;
        _hostServer.text = settings.address;
        _joinAddress.text = settings.address;
        _code.text = settings.lastRoom;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _hostServer.dispose();
    _joinAddress.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _playerName =>
      _name.text.trim().isEmpty ? 'Player' : _name.text.trim();

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppText.ui(size: 14)),
          backgroundColor: AppColors.feltRaised,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _host() async {
    final settings = _settings;
    if (settings == null || _busy) return;
    settings.name = _name.text;

    if (_hostOn == _HostOn.server) {
      final server = parseServerAddress(_hostServer.text);
      if (server == null) return _toast('Enter the server address.');
      settings.address = _hostServer.text;
      return _open(server, code: null);
    }

    setState(() => _busy = true);
    LocalHost? host;
    try {
      host = await startLocalHost(port: kDefaultGamePort);
    } catch (e) {
      if (mounted) _toast("Couldn't start hosting on this device: $e");
    }
    if (!mounted) {
      await host?.stop();
      return;
    }
    setState(() => _busy = false);
    if (host == null) return;
    await _open(
      Uri(scheme: 'ws', host: '127.0.0.1', port: host.port, path: '/'),
      code: null,
      host: host,
    );
  }

  Future<void> _join() async {
    final settings = _settings;
    if (settings == null || _busy) return;
    final server = parseServerAddress(_joinAddress.text);
    if (server == null) {
      return _toast("Enter the host's address (shown on their screen).");
    }
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}$').hasMatch(code)) {
      return _toast('Room codes are 4 letters.');
    }
    settings.name = _name.text;
    settings.address = _joinAddress.text;
    await _open(server, code: code);
  }

  Future<void> _open(Uri server, {String? code, LocalHost? host}) async {
    final settings = _settings!;
    final client = RemoteTableClient(
      server: server,
      name: _playerName,
      clientId: settings.clientId,
      roomCode: code,
      connect: widget.connector,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          client: client,
          localHost: host,
          serverLabel: host == null ? displayAddress(server) : null,
          onRoomCode: (code) => settings.lastRoom = code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _settings != null;
    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      TintIconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Play with friends', style: AppText.display(size: 40)),
                  const SizedBox(height: 8),
                  Text(
                    'Up to four players, each on their own device. Bots '
                    'fill any empty seats.',
                    style: AppText.ui(
                      size: 14,
                      color: AppColors.sage,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Field(
                    label: 'YOUR NAME',
                    controller: _name,
                    hint: 'Player',
                    maxLength: 20,
                  ),
                  const SizedBox(height: 32),
                  _Section(
                    title: 'Host a game',
                    children: [
                      _HostChoice(
                        value: _hostOn,
                        onChanged: (v) => setState(() => _hostOn = v),
                      ),
                      const SizedBox(height: 14),
                      if (_hostOn == _HostOn.thisDevice)
                        Text(
                          'Friends on the same Wi-Fi join using the address '
                          'and code shown in the room. Keep Spades open '
                          'while you host.',
                          style: AppText.ui(
                            size: 13,
                            color: AppColors.sage,
                            height: 1.5,
                          ),
                        )
                      else
                        _Field(
                          label: 'SERVER ADDRESS',
                          controller: _hostServer,
                          hint: 'spades.example.com or 192.168.1.20',
                          keyboardType: TextInputType.url,
                        ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: ready && !_busy ? _host : null,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.ink,
                                ),
                              )
                            : const Text('Create room'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _Section(
                    title: 'Join a game',
                    children: [
                      _Field(
                        label: 'HOST ADDRESS',
                        controller: _joinAddress,
                        hint: '192.168.1.20',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'ROOM CODE',
                        controller: _code,
                        hint: 'ABCD',
                        maxLength: 4,
                        capitalize: true,
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: ready && !_busy ? _join : null,
                        child: const Text('Join room'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.display(size: 24)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _HostChoice extends StatelessWidget {
  const _HostChoice({required this.value, required this.onChanged});

  final _HostOn value;
  final ValueChanged<_HostOn> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(_HostOn option, String label, {bool enabled = true}) {
      final selected = value == option;
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => onChanged(option) : null,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.feltHover : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.hairlineStrong : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: AppText.ui(
                size: 13,
                weight: FontWeight.w600,
                color: !enabled
                    ? AppColors.sage.withValues(alpha: 0.4)
                    : selected
                    ? AppColors.ivory
                    : AppColors.sage,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          option(
            _HostOn.thisDevice,
            'On this device',
            enabled: canHostOnThisDevice,
          ),
          option(_HostOn.server, 'On a server'),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.capitalize = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final bool capitalize;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(size: 10)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autocorrect: false,
          textCapitalization: capitalize
              ? TextCapitalization.characters
              : TextCapitalization.none,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            if (capitalize) _UpperCaseFormatter(),
          ],
          onSubmitted: onSubmitted,
          style: capitalize
              ? AppText.display(size: 24, height: 1.2)
              : AppText.ui(size: 16),
          cursorColor: AppColors.brass,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                (capitalize
                        ? AppText.display(size: 24, height: 1.2)
                        : AppText.ui(size: 16))
                    .copyWith(color: AppColors.sage.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.tint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: border(AppColors.hairline),
            focusedBorder: border(AppColors.brass),
          ),
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
