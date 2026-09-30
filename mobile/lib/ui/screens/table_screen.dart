import 'package:flutter/material.dart';
import 'package:spades_engine/multiplayer.dart';
import 'package:spades_engine/spades_engine.dart';

import '../../state/table_client.dart';
import '../table_perspective.dart';
import '../theme/app_theme.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/hand_fan.dart';
import '../widgets/score_history_dialog.dart';
import '../widgets/scoreboard_bar.dart';
import '../widgets/trick_area.dart';

/// The card table, drawn from the viewing player's chair. Works the same
/// for single-player and multiplayer: it only reads [client]'s view and
/// sends actions back through it.
class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.client,
    this.onLeave,
    this.leaveWarning,
  });

  final TableClient client;

  /// Replaces the default "are you sure" text in the leave dialog.
  final String? leaveWarning;

  /// Called once the player confirms leaving; it takes over leaving the
  /// game and closing the screen. By default the client leaves and the
  /// route pops.
  final VoidCallback? onLeave;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  @override
  void initState() {
    super.initState();
    widget.client.addListener(_onClientChanged);
  }

  @override
  void didUpdateWidget(TableScreen old) {
    super.didUpdateWidget(old);
    if (old.client != widget.client) {
      old.client.removeListener(_onClientChanged);
      widget.client.addListener(_onClientChanged);
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientChanged);
    super.dispose();
  }

  void _onClientChanged() {
    final error = widget.client.takeError();
    if (error != null && mounted) {
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
    if (mounted) setState(() {});
  }

  Future<void> _confirmLeave() async {
    final multiplayer = widget.client.isMultiplayer;
    final leave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.felt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.hairline),
        ),
        title: Text('Leave this game?', style: AppText.display(size: 28)),
        content: Text(
          widget.leaveWarning ??
              (multiplayer
                  ? 'A bot will take over your seat. You can rejoin with '
                        'the room code while the game is still going.'
                  : 'This match will be lost.'),
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
              'Leave',
              style: AppText.ui(
                color: AppColors.brass,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    _leave();
  }

  void _leave() {
    if (widget.onLeave != null) {
      widget.onLeave!();
    } else {
      widget.client.leave();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final view = client.view;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (view?.matchOver ?? false) {
          _leave();
        } else {
          _confirmLeave();
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: feltTableDecoration(),
          child: SafeArea(
            child: view == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brass),
                  )
                : _Table(
                    client: client,
                    view: view,
                    onLeave: _confirmLeave,
                    onFinished: _leave,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.client,
    required this.view,
    required this.onLeave,
    required this.onFinished,
  });

  final TableClient client;
  final TableView view;
  final VoidCallback onLeave;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final p = TablePerspective(view);
    final partnerBid = view.info(p.me.partner).bid;

    return Column(
      children: [
        if (client.status == ConnectionStatus.reconnecting ||
            client.status == ConnectionStatus.connecting)
          const _ConnectionBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ScoreboardBar(
            usLabel: p.usLabel,
            themLabel: p.themLabel,
            usScore: view.teamScores[p.us]!,
            themScore: view.teamScores[p.them]!,
            config: view.config,
            roundNumber: view.roundNumber,
            handSize: view.handSize,
            leading: TintIconButton(
              tooltip: 'Leave game',
              onPressed: onLeave,
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.text,
              ),
            ),
            trailing: ScoreHistoryButton(view: view),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: const Alignment(0, -0.95),
                child: _OpponentSeat(
                  seat: p.fromScreen(Seat.north),
                  view: view,
                  showHand: true,
                ),
              ),
              Align(
                alignment: const Alignment(-0.94, -0.62),
                child: _OpponentSeat(seat: p.fromScreen(Seat.west), view: view),
              ),
              Align(
                alignment: const Alignment(0.94, -0.62),
                child: _OpponentSeat(seat: p.fromScreen(Seat.east), view: view),
              ),
              TrickArea(
                plays: {
                  for (final e in view.trickPlays) p.toScreen(e.key): e.value,
                },
                winner: view.trickWinner == null
                    ? null
                    : p.toScreen(view.trickWinner!),
              ),
              if (view.isMyBidTurn)
                BidPanel(
                  config: view.config,
                  handSize: view.handSize,
                  maxBid: view.maxBid,
                  partnerBid: partnerBid,
                  partnerName: p.name(p.me.partner),
                  isFirstBidOfHand: view.isFirstBid,
                  blindNilEligible: view.config.blindNilEnabled,
                  onBid: client.bid,
                ),
              if (view.phase == HandPhase.complete)
                _HandSummaryOverlay(
                  view: view,
                  onNextHand: client.nextHand,
                  onFinished: onFinished,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HumanSeat(view: view, onPlay: client.play),
        ),
      ],
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.brass.withValues(alpha: 0.14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.brass,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Reconnecting…',
            style: AppText.ui(size: 12, color: AppColors.brass),
          ),
        ],
      ),
    );
  }
}

/// "bid 2 · won 1" while playing, "bid 2" while bidding, nothing before
/// the seat has bid — followed by any connection trouble ("offline",
/// "bot playing").
String? _seatDetail(TableView view, Seat seat) {
  final info = view.info(seat);
  final bid = info.bid;
  final parts = [
    if (bid != null)
      view.phase == HandPhase.bidding
          ? 'bid $bid'
          : 'bid $bid · won ${info.tricksWon}',
    if (info.autopilot) 'bot playing' else if (!info.connected) 'offline',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({
    required this.seat,
    required this.view,
    this.showHand = false,
  });

  final Seat seat;
  final TableView view;

  /// Only the player across (screen North) shows a hand; the side seats
  /// stay a single tag so they never crowd the trick.
  final bool showHand;

  @override
  Widget build(BuildContext context) {
    final tag = _SeatTag(
      name: view.info(seat).name,
      detail: _seatDetail(view, seat),
      acting: view.toAct == seat,
      dimmed: !view.info(seat).connected,
    );
    if (!showHand) return tag;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tag,
        const SizedBox(height: 10),
        _MiniBacks(count: view.info(seat).cardCount),
      ],
    );
  }
}

/// An opponent's hand as a tidy stack of small card backs — present, but
/// never louder than the cards in play.
class _MiniBacks extends StatelessWidget {
  const _MiniBacks({required this.count});

  final int count;

  static const _w = 26.0;
  static const _h = 36.0;
  static const _step = 10.0;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox(height: _h);
    return SizedBox(
      width: _w + _step * (count - 1),
      height: _h,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: _step * i,
              child: Container(
                width: _w,
                height: _h,
                decoration: BoxDecoration(
                  color: AppColors.feltRaised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.brass.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seat tag: a tint pill at rest; a brass hairline with a brass dot while
/// that player is deciding.
class _SeatTag extends StatelessWidget {
  const _SeatTag({
    required this.name,
    this.detail,
    required this.acting,
    this.dimmed = false,
  });

  final String name;
  final String? detail;
  final bool acting;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.quick,
      opacity: dimmed ? 0.6 : 1,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        height: 28,
        constraints: const BoxConstraints(maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: acting ? AppColors.brass : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acting) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.brass,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(size: 12, weight: FontWeight.w600),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 8),
              Text(
                detail!,
                maxLines: 1,
                style: AppText.ui(size: 12, color: AppColors.sage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HumanSeat extends StatelessWidget {
  const _HumanSeat({required this.view, required this.onPlay});

  final TableView view;
  final ValueChanged<PlayingCard> onPlay;

  @override
  Widget build(BuildContext context) {
    final me = view.seat;
    final hand = view.hand;
    final bid = view.info(me).bid;
    final acting = view.isMyBidTurn || view.isMyPlayTurn;

    String? turnLabel;
    if (view.isMyBidTurn) {
      turnLabel = 'Your turn to bid';
    } else if (view.isMyPlayTurn) {
      final lead = view.trickPlays.isEmpty
          ? null
          : view.trickPlays.first.value.suit;
      turnLabel = lead == null
          ? 'Your turn · lead'
          : hand.any((c) => c.suit == lead)
          ? 'Your turn · follow ${lead.name}'
          : 'Your turn';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (acting)
          _YourTurnPill(label: turnLabel!)
        else
          _SeatTag(name: 'You', detail: _seatDetail(view, me), acting: false),
        if (acting && bid != null) ...[
          const SizedBox(height: 8),
          Text(
            'You bid $bid · won ${view.info(me).tricksWon}',
            style: AppText.ui(size: 12, color: AppColors.sage),
          ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HandFan(
              cards: hand,
              faceUp: true,
              cardWidth: 66,
              legalCards: view.isMyPlayTurn ? view.legalCards : null,
              onCardTap: view.isMyPlayTurn ? onPlay : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one solid brass element on the table: it only appears when the
/// game is waiting on you.
class _YourTurnPill extends StatelessWidget {
  const _YourTurnPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.brass,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.ui(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _HandSummaryOverlay extends StatelessWidget {
  const _HandSummaryOverlay({
    required this.view,
    required this.onNextHand,
    required this.onFinished,
  });

  final TableView view;
  final VoidCallback onNextHand;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final p = TablePerspective(view);
    final results = view.history.last;
    final finished = view.matchOver;
    final waitingOn = [
      for (final s in view.awaitingReady)
        if (s != p.me) p.name(s),
    ];

    final String title;
    if (finished) {
      title = view.winner == p.us ? 'You win the match' : '${p.themLabel} win';
    } else {
      title = 'Round ${view.roundNumber} complete';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.felt.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.display(size: 30)),
          const SizedBox(height: 18),
          for (final team in [p.us, p.them]) ...[
            _SummaryRow(
              label: p.teamLabel(team),
              line: results[team]!,
              total: view.teamScores[team]!,
            ),
            if (team == p.us)
              const Divider(height: 1, color: AppColors.hairline),
          ],
          const SizedBox(height: 22),
          if (finished)
            ElevatedButton(
              onPressed: onFinished,
              child: const Text('Back to menu'),
            )
          else if (view.iAmReady)
            OutlinedButton(
              onPressed: null,
              child: Text(
                waitingOn.isEmpty
                    ? 'Dealing…'
                    : 'Waiting for ${waitingOn.join(' & ')}',
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            ElevatedButton(
              onPressed: onNextHand,
              child: const Text('Next hand'),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.line,
    required this.total,
  });

  final String label;
  final HandLine line;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(size: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  'bid ${line.bid} · won ${line.won}',
                  style: AppText.ui(size: 13, color: AppColors.sage),
                ),
              ],
            ),
          ),
          Text(
            formatDelta(line.delta),
            style: AppText.display(
              size: 24,
              color: line.delta < 0 ? AppColors.loss : AppColors.text,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            child: Text(
              formatScore(total),
              textAlign: TextAlign.end,
              style: AppText.display(size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
