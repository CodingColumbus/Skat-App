import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/bot.dart' show estimateValue;
import '../logic/cards.dart';
import '../logic/models.dart';
import '../logic/rules.dart';
import '../logic/view.dart';
import '../net/controller.dart';
import '../state/settings.dart';
import 'card_widget.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'suit_shapes.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;
  final Set<SkatCard> _sel = {};
  GameType? _picked;
  bool _handMode = false;
  SkatCard? _armed;
  int _lastRound = -1;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _resetPick() {
    _sel.clear();
    _picked = null;
    _handMode = false;
    _armed = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Spiel verlassen?'),
            content: Text(c.isOnline ? 'Der Tisch wird für alle geschlossen bzw. du verlässt ihn.' : 'Der aktuelle Stand geht verloren.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Weiterspielen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verlassen')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final v = c.view;
          if (v != null && v.round != _lastRound) {
            _lastRound = v.round;
            _resetPick();
          }
          return Scaffold(
            backgroundColor: Color.lerp(s.table, Colors.black, 0.45),
            appBar: _appBar(v),
            body: SafeArea(
              child: Stack(children: [
                if (v == null)
                  Center(child: Text(c.status ?? 'Warte auf den Host …', style: const TextStyle(color: Colors.white)))
                else
                  Column(children: [
                    _opponents(v, s),
                    Expanded(child: _table(v, s)),
                    _messageBar(v),
                    _actions(v, s),
                    _hand(v, s),
                    const SizedBox(height: 6),
                  ]),
                if (c.status != null && v != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Material(color: Colors.red.shade800, child: Padding(padding: const EdgeInsets.all(8), child: Text(c.status!, style: const TextStyle(color: Colors.white)))),
                  ),
                if (c.handoffSeat != null && v != null) _handoff(v),
              ]),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar(GameView? v) => AppBar(
        title: Text(c.isOnline ? 'Skat · WLAN' : 'Skat'),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        actions: [
          if (v != null && v.lastTrick.isNotEmpty)
            IconButton(icon: const Icon(Icons.history), tooltip: 'Letzter Stich', onPressed: () => _showLastTrick(v)),
          if (v != null) IconButton(icon: const Icon(Icons.leaderboard), tooltip: 'Spielstand', onPressed: () => _showTotals(v)),
          PopupMenuButton<String>(
            onSelected: (x) {
              if (x == 'rules') Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen()));
              if (x == 'settings') Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rules', child: Text('Regeln')),
              PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
            ],
          ),
        ],
      );

  Widget _handoff(GameView v) {
    final name = v.names[c.handoffSeat!];
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF101418),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.swap_horiz, size: 64, color: Colors.white70),
          const SizedBox(height: 16),
          Text('Gerät an $name weitergeben', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Die anderen bitte wegschauen.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: c.confirmHandoff,
            icon: const Icon(Icons.visibility),
            label: Text('Ich bin $name'),
          ),
        ]),
      ),
    );
  }

  void _showTotals(GameView v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spielstand'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < v.n; i++)
            ListTile(
              dense: true,
              title: Text(v.names[i]),
              trailing: Text('${v.totals[i]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
        ]),
        actions: [
          if (c.canResetTotals) TextButton(onPressed: () { c.resetTotals(); Navigator.pop(context); }, child: const Text('Zurücksetzen')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );
  }

  void _showLastTrick(GameView v) {
    final st = SettingsScope.of(context).cardStyle;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Letzter Stich'),
        content: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < v.lastTrick.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CardView(card: v.lastTrick[i], width: 56, style: st, highlight: v.lastTrickSeats[i] == v.lastTrickWinner),
                const SizedBox(height: 4),
                Text(v.names[v.lastTrickSeats[i]], style: const TextStyle(fontSize: 11)),
              ]),
            ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  // ---------- Gegner ----------
  List<int> _others(GameView v) => [for (var k = 1; k < v.n; k++) (v.mySeat + k) % v.n];

  String _role(GameView v, int seat) {
    final p = <String>[];
    if (v.declarer == seat && v.game != null) p.add('Alleinspieler');
    if (v.n == 4 && v.dealer == seat) p.add('Geber (setzt aus)');
    return p.join(' · ');
  }

  Widget _opponents(GameView v, Settings s) {
    return Row(children: [
      for (final seat in _others(v))
        Expanded(
          child: Builder(builder: (_) {
            final active = v.actingSeat == seat;
            final sitsOut = v.n == 4 && v.dealer == seat;
            return Container(
              margin: const EdgeInsets.fromLTRB(4, 6, 4, 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? Colors.amber : Colors.transparent, width: 2),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (v.isBot[seat]) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.smart_toy, size: 14, color: Colors.white70)),
                  Flexible(child: Text(v.names[seat], overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 4),
                SizedBox(
                  height: 34,
                  child: sitsOut
                      ? const Center(child: Text('—', style: TextStyle(color: Colors.white54)))
                      : Stack(children: [
                          for (var i = 0; i < v.handSizes[seat]; i++)
                            Positioned(left: i * 6.0, child: CardView(width: 22, style: s.cardStyle)),
                        ]),
                ),
                const SizedBox(height: 2),
                Text(
                  _role(v, seat).isEmpty ? ' ' : _role(v, seat),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                ),
                Text(
                  '${v.totals[seat]} Pkt.${s.showOpponentTricks && v.game != null ? ' · ${v.tricksWon[seat]} St.' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ]),
            );
          }),
        ),
    ]);
  }

  // ---------- Tisch ----------
  Alignment _slot(GameView v, int seat) {
    final rel = (seat - v.mySeat + v.n) % v.n;
    if (rel == 0) return const Alignment(0, 0.85);
    if (v.n == 3) return rel == 1 ? const Alignment(-0.75, -0.25) : const Alignment(0.75, -0.25);
    return switch (rel) {
      1 => const Alignment(-0.85, 0.05),
      2 => const Alignment(0, -0.8),
      _ => const Alignment(0.85, 0.05),
    };
  }

  Widget _table(GameView v, Settings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: RadialGradient(colors: [Color.lerp(s.table, Colors.white, 0.12)!, s.table, Color.lerp(s.table, Colors.black, 0.25)!], stops: const [0, .6, 1]),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Stack(children: [
          for (var i = 0; i < v.trick.length; i++)
            Align(alignment: _slot(v, v.trickSeats[i]), child: CardView(card: v.trick[i], width: 60 * s.cardScale, style: s.cardStyle)),
          if (v.game != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: _chip('${v.names[v.declarer!]} spielt ${suitGameLabel(v.game!, s.cardStyle)}${v.isHand ? ' Hand' : ''}')),
            ),
          if (s.showAugen && v.game != null && v.phase != Phase.roundOver)
            Positioned(left: 10, bottom: 8, child: _chip('Augen: ${v.myAugen}', small: true)),
          if (v.phase == Phase.bidding)
            Center(child: _chip(v.bid == 0 ? 'Reizen' : 'Gebot: ${v.bid}')),
          if (v.phase == Phase.roundOver && v.result != null) Center(child: _resultCard(v, s)),
        ]),
      ),
    );
  }

  String suitGameLabel(GameType g, CardStyle st) => g.kind == GameKind.suit ? suitName(g.trump!, st) : g.label;

  Widget _chip(String t, {bool small = false}) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
        child: Text(t, style: TextStyle(color: Colors.white, fontSize: small ? 12 : 14)),
      );

  Widget _resultCard(GameView v, Settings s) {
    final r = v.result!;
    return Card(
      margin: const EdgeInsets.all(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(r.score > 0 ? '${v.names[r.declarer]} gewinnt' : '${v.names[r.declarer]} verliert',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${suitGameLabel(r.game, s.cardStyle)}${r.hand ? ' Hand' : ''}'
              '${r.game.isNull ? '' : ' · ${r.declarerPoints} Augen'}'
              '${r.schneider ? ' · Schneider' : ''}${r.schwarz ? ' · Schwarz' : ''}'),
          Text('Spielwert ${r.gameValue} → ${r.score > 0 ? '+' : ''}${r.score}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (v.revealedSkat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(v.isHand ? 'Skat:' : 'Gedrückt:', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final k in v.revealedSkat) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: CardView(card: k, width: 34, style: s.cardStyle)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _messageBar(GameView v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
        child: Text(v.message, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
      );

  // ---------- Aktionen ----------
  Widget _btn(String t, VoidCallback? f, {bool primary = true}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: primary
            ? FilledButton(onPressed: f, child: Text(t))
            : OutlinedButton(
                onPressed: f,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                child: Text(t),
              ),
      );

  Widget _row(List<Widget> kids) => SizedBox(height: 52, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: kids));

  Widget _actions(GameView v, Settings s) {
    final mine = v.actingSeat == v.mySeat;
    switch (v.phase) {
      case Phase.bidding:
        if (!mine) return _row([_waiting(v)]);
        return _row(v.callerToAct
            ? [_btn('Sagen ${v.nextBid}', c.bidCall), _btn('Passen', c.bidPass, primary: false)]
            : [_btn('Halten (${v.bid})', c.bidHold), _btn('Passen', c.bidPass, primary: false)]);
      case Phase.decide18:
        if (!mine) return _row([_waiting(v)]);
        return _row([_btn('Spielen (18)', () => c.decide18(true)), _btn('Einwerfen', () => c.decide18(false), primary: false)]);
      case Phase.handDecision:
        if (!mine) return _row([_waiting(v)]);
        if (_handMode) return _picker(v, handMode: true);
        return _row([
          _btn('Skat aufnehmen', () {
            _resetPick();
            c.pickUp();
          }),
          _btn('Hand spielen', () => setState(() => _handMode = true), primary: false),
        ]);
      case Phase.discard:
        if (!mine) return _row([_waiting(v)]);
        return _picker(v, handMode: false);
      case Phase.allPassed:
      case Phase.roundOver:
        return _row([_btn('Nächste Runde', c.nextRound)]);
      default:
        return _row(const []);
    }
  }

  Widget _waiting(GameView v) {
    final a = v.actingSeat;
    return Text(a == null ? '' : 'Warte auf ${v.names[a]} …', style: const TextStyle(color: Colors.white70));
  }

  Widget _picker(GameView v, {required bool handMode}) {
    final s = SettingsScope.of(context);
    final games = <GameType>[
      for (final x in Suit.values.reversed) GameType.suit(x),
      const GameType.grand(),
      const GameType.nullGame(),
    ];
    final ready = _picked != null && (handMode || _sel.length == 2);
    final cards = v.myHand;
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
          for (final t in games)
            ChoiceChip(
              avatar: t.kind == GameKind.suit ? SuitIcon(t.trump!, s.cardStyle) : null,
              label: Text(suitGameLabel(t, s.cardStyle)),
              selected: _picked == t,
              onSelected: (_) => setState(() => _picked = t),
            ),
        ]),
        if (_picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Spielwert ca. ${estimateValue(cards, _picked!, hand: handMode)}  ·  Gebot ${v.bid}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!handMode)
            const Padding(padding: EdgeInsets.only(right: 8), child: Text('2 Karten drücken', style: TextStyle(color: Colors.white, fontSize: 12))),
          FilledButton(
            onPressed: ready
                ? () {
                    final t = _picked!;
                    if (handMode) {
                      _resetPick();
                      c.playHand(t);
                    } else {
                      final two = _sel.toList();
                      _resetPick();
                      c.discard(two, t);
                    }
                  }
                : null,
            child: Text(handMode ? 'Hand spielen' : 'Drücken & Spielen'),
          ),
          if (handMode) TextButton(onPressed: () => setState(_resetPick), child: const Text('Zurück')),
        ]),
      ]),
    );
  }

  // ---------- Hand ----------
  String _whyIllegal(GameView v) {
    if (v.trick.isEmpty || v.game == null) return 'Diese Karte ist gerade nicht spielbar.';
    final lead = v.trick.first;
    if (isTrump(lead, v.game!)) return 'Du musst Trumpf zugeben.';
    return 'Du musst ${suitName(lead.suit, SettingsScope.of(context).cardStyle)} bedienen.';
  }

  Widget _hand(GameView v, Settings s) {
    final cards = v.myHand;
    final playing = v.phase == Phase.playing && v.actingSeat == v.mySeat;
    final discarding = v.phase == Phase.discard && v.actingSeat == v.mySeat;
    final w = 62.0 * s.cardScale;
    return LayoutBuilder(builder: (context, box) {
      final n = cards.length.clamp(1, 12);
      final step = n <= 1 ? 0.0 : ((box.maxWidth - w - 16) / (n - 1)).clamp(16.0, w * 0.9);
      final total = w + step * (n - 1);
      return SizedBox(
        height: w / kCardAspect + 22,
        child: Center(
          child: SizedBox(
            width: total,
            child: Stack(clipBehavior: Clip.none, children: [
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: i * step,
                  top: 20,
                  child: Builder(builder: (_) {
                    final card = cards[i];
                    final legal = v.legal.contains(card);
                    return CardView(
                      card: card,
                      width: w,
                      style: s.cardStyle,
                      selected: _sel.contains(card) || _armed == card,
                      dimmed: playing && s.showLegalHint && !legal,
                      onTap: () {
                        if (discarding) {
                          setState(() {
                            if (!_sel.remove(card) && _sel.length < 2) _sel.add(card);
                          });
                        } else if (playing) {
                          if (!legal) {
                            ScaffoldMessenger.of(context)
                              ..clearSnackBars()
                              ..showSnackBar(SnackBar(content: Text(_whyIllegal(v)), duration: const Duration(seconds: 2)));
                            return;
                          }
                          if (s.doubleTapToPlay && _armed != card) {
                            setState(() => _armed = card);
                            return;
                          }
                          _armed = null;
                          if (s.haptics) HapticFeedback.lightImpact();
                          c.playCard(card);
                        }
                      },
                    );
                  }),
                ),
            ]),
          ),
        ),
      );
    });
  }
}
