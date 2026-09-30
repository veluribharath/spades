import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

import '../../net/local_host.dart';
import '../../net/server_address.dart';
import '../../state/remote_table_client.dart';
import '../../state/table_client.dart';
import '../theme/app_theme.dart';
import '../widgets/score_history_dialog.dart';
import 'table_screen.dart';

/// One multiplayer room: the lobby until the host starts, then the table.
/// Owns the connection (and the on-device server when hosting here).
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.client,
    this.localHost,
    this.serverLabel,
    this.onRoomCode,
  });

  final RemoteTableClient client;

  /// Set when this device is the host's server.
  final LocalHost? localHost;

  /// How to describe the server to friends when not hosting locally.
  final String? serverLabel;

  /// Called once the room code is known (to remember it).
  final ValueChanged<String>? onRoomCode;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  String? _reportedCode;
  bool _exiting = false;

  RemoteTableClient get _client => widget.client;

  @override
  void initState() {
    super.initState();
    _client.addListener(_changed);
  }

  @override
  void dispose() {
    _client.removeListener(_changed);
    _client.dispose();
    widget.localHost?.stop();
    super.dispose();
  }

  void _changed() {
    final room = _client.room;
    final code = room?.code;
    if (code != null && code != _reportedCode) {
      _reportedCode = code;
      widget.onRoomCode?.call(code);
    }
    // Once the table is up, TableScreen shows errors itself.
    if (!(room?.started ?? false) && mounted) {
      final error = _client.takeError();
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error, style: AppText.ui(size: 14)),
              backgroundColor: AppColors.feltRaised,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    if (widget.localHost != null && !(_client.view?.matchOver ?? false)) {
      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.felt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.hairline),
          ),
          title: Text('Close the room?', style: AppText.display(size: 28)),
          content: Text(
            'You are hosting on this device — leaving ends the game for '
            'everyone.',
            style: AppText.ui(size: 14, color: AppColors.sage, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Stay', style: AppText.ui(color: AppColors.text)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Close room',
                style: AppText.ui(
                  color: AppColors.brass,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _exit();
  }

  /// Leaves the room and closes this screen. A host closes the room
  /// outright — server first — so nobody briefly sees a half-left room
  /// (e.g. being promoted to host) before it disappears.
  Future<void> _exit() async {
    // Stopping a host can take a moment; a second tap mustn't pop twice.
    if (_exiting) return;
    _exiting = true;
    final host = widget.localHost;
    if (host != null) {
      _client.close();
      await host.stop();
    } else {
      _client.leave();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fatal = _client.fatalError;
    final room = _client.room;

    if (fatal != null) {
      return _Message(
        title: room == null ? "Couldn't join" : 'Disconnected',
        body: fatal,
        action: 'Back',
        onAction: () => Navigator.of(context).pop(),
      );
    }
    if (room == null) {
      return _Message(
        title: 'Connecting…',
        body: widget.localHost != null
            ? 'Opening your room.'
            : 'Reaching ${displayAddress(_client.server)}.',
        action: 'Cancel',
        onAction: _exit,
        busy: true,
      );
    }
    if (room.started && room.view != null) {
      return TableScreen(
        client: _client,
        onLeave: _exit,
        leaveWarning: widget.localHost != null
            ? 'You are hosting on this device — leaving ends the game for '
                  'everyone.'
            : null,
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _Lobby(
        client: _client,
        room: room,
        localHost: widget.localHost,
        serverLabel: widget.serverLabel,
        onLeave: _leave,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.busy = false,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy) ...[
                      const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brass,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.display(size: 34),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: AppText.ui(
                        size: 14,
                        color: AppColors.sage,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton(onPressed: onAction, child: Text(action)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.client,
    required this.room,
    required this.localHost,
    required this.serverLabel,
    required this.onLeave,
  });

  final RemoteTableClient client;
  final RoomSnapshot room;
  final LocalHost? localHost;
  final String? serverLabel;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final host = room.seats.where((s) => s.isHost).firstOrNull;
    final humans = room.seats.where((s) => !s.isEmpty && !s.isBot).length;
    final emptySeats = room.seats.where((s) => s.isEmpty).length;

    final String joinAt;
    final lh = localHost;
    if (lh != null) {
      final address = lh.addresses.isEmpty ? null : lh.addresses.first;
      final port = lh.port == kDefaultGamePort ? '' : ':${lh.port}';
      joinAt = address == null
          ? 'this device (no Wi-Fi address found)'
          : '$address$port';
    } else {
      joinAt = serverLabel ?? displayAddress(client.server);
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  if (client.status == ConnectionStatus.reconnecting)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: AppColors.brass.withValues(alpha: 0.14),
                      child: Text(
                        'Reconnecting…',
                        textAlign: TextAlign.center,
                        style: AppText.ui(size: 12, color: AppColors.brass),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        Row(
                          children: [
                            TintIconButton(
                              tooltip: 'Leave room',
                              onPressed: onLeave,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('ROOM CODE', style: AppText.label()),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  room.code.split('').join(' '),
                                  style: AppText.display(size: 56),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TintIconButton(
                              tooltip: 'Copy code',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: room.code),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Room code copied',
                                      style: AppText.ui(size: 14),
                                    ),
                                    backgroundColor: AppColors.feltRaised,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: AppColors.brass,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Friends join at '),
                              TextSpan(
                                text: joinAt,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: localHost != null
                                    ? ' with this code. Everyone needs to be '
                                          'on the same Wi-Fi, and Spades has '
                                          'to stay open on this device.'
                                    : ' with this code.',
                              ),
                            ],
                          ),
                          style: AppText.ui(
                            size: 14,
                            color: AppColors.sage,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _TeamGroup(
                          label: 'SOUTH & NORTH',
                          seats: [
                            room.seats[Seat.south.index],
                            room.seats[Seat.north.index],
                          ],
                          client: client,
                          isHost: room.youAreHost,
                        ),
                        const SizedBox(height: 18),
                        _TeamGroup(
                          label: 'WEST & EAST',
                          seats: [
                            room.seats[Seat.west.index],
                            room.seats[Seat.east.index],
                          ],
                          client: client,
                          isHost: room.youAreHost,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Partners sit opposite each other. Tap an open '
                          'seat to move.',
                          style: AppText.ui(size: 12, color: AppColors.sage),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: room.youAreHost
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: client.start,
                                child: Text(
                                  humans == 1
                                      ? 'Start with bots'
                                      : 'Start game',
                                ),
                              ),
                              if (emptySeats > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  emptySeats == 1
                                      ? 'The empty seat will be played by a '
                                            'bot.'
                                      : 'Empty seats will be played by bots.',
                                  textAlign: TextAlign.center,
                                  style: AppText.ui(
                                    size: 12,
                                    color: AppColors.sage,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            'Waiting for ${host?.name ?? 'the host'} to '
                            'start…',
                            textAlign: TextAlign.center,
                            style: AppText.ui(size: 14, color: AppColors.sage),
                          ),
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

class _TeamGroup extends StatelessWidget {
  const _TeamGroup({
    required this.label,
    required this.seats,
    required this.client,
    required this.isHost,
  });

  final String label;
  final List<LobbySeat> seats;
  final RemoteTableClient client;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.label(size: 10)),
        const SizedBox(height: 8),
        for (final seat in seats) ...[
          _SeatRow(seat: seat, client: client, isHost: isHost),
          if (seat != seats.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.seat,
    required this.client,
    required this.isHost,
  });

  final LobbySeat seat;
  final RemoteTableClient client;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final compass =
        '${seat.seat.name[0].toUpperCase()}${seat.seat.name.substring(1)}';
    final canSit = !seat.isYou && (seat.isEmpty || seat.isBot);

    final String title;
    final String? detail;
    if (seat.isEmpty) {
      title = 'Open seat';
      detail = null;
    } else if (seat.isBot) {
      title = 'Bot';
      detail = null;
    } else {
      title = seat.isYou ? '${seat.name} (you)' : seat.name!;
      detail = [
        if (seat.isHost) 'host',
        if (!seat.connected) 'reconnecting',
      ].join(' · ');
    }

    return Material(
      color: seat.isEmpty ? Colors.transparent : AppColors.tint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canSit ? () => client.sit(seat.seat) : null,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seat.isYou
                  ? AppColors.brass
                  : seat.isEmpty
                  ? AppColors.hairlineStrong
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  compass.toUpperCase(),
                  style: AppText.label(size: 10),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        size: 15,
                        weight: FontWeight.w600,
                        color: seat.isEmpty || seat.isBot
                            ? AppColors.sage
                            : AppColors.ivory,
                      ),
                    ),
                    if (detail != null && detail.isNotEmpty)
                      Text(
                        detail,
                        style: AppText.ui(size: 12, color: AppColors.sage),
                      ),
                  ],
                ),
              ),
              if (canSit)
                Text(
                  'Sit here',
                  style: AppText.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.brass,
                  ),
                ),
              if (isHost && (seat.isEmpty || seat.isBot)) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => client.setBot(seat.seat, bot: seat.isEmpty),
                  child: Text(
                    seat.isEmpty ? 'Add bot' : 'Remove',
                    style: AppText.ui(size: 13, color: AppColors.sage),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
