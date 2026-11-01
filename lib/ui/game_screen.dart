import 'package:flutter/material.dart';
import '../logic/bot.dart';
import '../logic/cards.dart';
import '../logic/game.dart';
import '../logic/rules.dart';
import 'card_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final SkatGame g = SkatGame();
  final Set<SkatCard> _sel = {};
  GameType? _picked;
  bool _handMode = false;

  @override
  void dispose() {
    g.dispose();
    super.dispose();
  }

  void _resetPick() {
    _sel.clear();
    _picked = null;
    _handMode = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14532D),
      appBar: AppBar(
        title: const Text('Skat gegen Bots'),
        backgroundColor: const Color(0xFF0F3D21),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Punkte',
            onPressed: _showTotals,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: g,
          builder: (context, _) => Column(
            children: [
              _opponents(),
              Expanded(child: _table()),
              _messageBar(),
              _actions(),
              _hand(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showTotals() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spielstand'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            ListTile(dense: true, title: Text(g.names[i]), trailing: Text('${g.totals[i]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        actions: [
          TextButton(onPressed: () { g.resetTotals(); Navigator.pop(context); }, child: const Text('Zurücksetzen')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );
  }

  String _role(int seat) {
    final parts = <String>[];
    if (g.declarer == seat) parts.add('Alleinspieler');
    if (g.phase == Phase.bidding && g.bidActor == seat) parts.add('am Zug');
    if (g.phase == Phase.playing && g.turn == seat) parts.add('am Zug');
    return parts.join(' · ');
  }

  Widget _opponentBox(int seat) {
    final active = (g.phase == Phase.playing && g.turn == seat) || (g.phase == Phase.bidding && g.bidActor == seat);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.amber : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Text(g.names[seat], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          SizedBox(height: 40, child: _miniFan(g.hands[seat].length)),
          const SizedBox(height: 4),
          Text(_role(seat).isEmpty ? ' ' : _role(seat), style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
          Text('Gesamt: ${g.totals[seat]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _miniFan(int n) {
    return Stack(children: [
      for (var i = 0; i < n; i++)
        Positioned(left: i * 9.0, child: const CardView(width: 28)),
    ]);
  }

  Widget _opponents() => Row(children: [_opponentBox(1), _opponentBox(2)]);

  Widget _table() {
    Widget slot(int seat, Alignment a) {
      final i = g.trickSeats.indexOf(seat);
      return Align(alignment: a, child: i < 0 ? const SizedBox() : CardView(card: g.trick[i], width: 62));
    }

    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        Center(
          child: Container(
            width: c.maxWidth * 0.92,
            height: c.maxHeight * 0.96,
            decoration: BoxDecoration(color: const Color(0xFF1B6B3A), borderRadius: BorderRadius.circular(24)),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Stack(children: [
          slot(1, const Alignment(-0.7, -0.4)),
          slot(2, const Alignment(0.7, -0.4)),
          slot(0, const Alignment(0, 0.8)),
        ])),
        if (g.game != null)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                child: Text('${g.game!.label}${g.isHand ? ' Hand' : ''} · ${g.names[g.declarer!]}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        if (g.phase == Phase.roundOver) Center(child: _resultCard()),
      ]);
    });
  }

  Widget _resultCard() {
    final r = g.result!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(r.won ? '${g.names[r.declarer]} gewinnt' : '${g.names[r.declarer]} verliert',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${r.game.label}${r.hand ? ' Hand' : ''}'
              '${r.game.isNull ? '' : ' · ${r.declarerPoints} Augen'}'
              '${r.schneider ? ' · Schneider' : ''}${r.schwarz ? ' · Schwarz' : ''}'),
          Text('Spielwert ${r.gameValue}  →  ${r.score > 0 ? '+' : ''}${r.score} Punkte',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _messageBar() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Text(g.message, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
      );

  Widget _btn(String t, VoidCallback? f, {bool primary = true}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: primary
            ? FilledButton(onPressed: f, child: Text(t))
            : OutlinedButton(
                onPressed: f,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                child: Text(t)),
      );

  Widget _actions() {
    final row = <Widget>[];
    switch (g.phase) {
      case Phase.bidding:
        if (g.bidActor == 0) {
          if (g.callerToAct) {
            row.addAll([_btn('Sagen ${g.nextBid}', g.humanBid), _btn('Passen', g.humanPass, primary: false)]);
          } else {
            row.addAll([_btn('Halten (${g.bid})', g.humanHold), _btn('Passen', g.humanPass, primary: false)]);
          }
        }
      case Phase.decide18:
        if (g.declarer == 0) {
          row.addAll([_btn('Spielen (18)', () => g.decide18(true)), _btn('Einwerfen', () => g.decide18(false), primary: false)]);
        }
      case Phase.handDecision:
        if (g.declarer == 0) {
          row.addAll([
            _btn('Skat aufnehmen', () { _resetPick(); g.pickUpSkat(); }),
            _btn('Hand spielen', () => setState(() { _handMode = true; })),
          ]);
          if (_handMode) return _gamePicker(handMode: true);
        }
      case Phase.discard:
        if (g.declarer == 0) return _gamePicker(handMode: false);
      case Phase.allPassed:
        row.add(_btn('Neu geben', () { _resetPick(); g.newRound(); }));
      case Phase.roundOver:
        row.add(_btn('Nächste Runde', () { _resetPick(); g.newRound(); }));
      default:
        break;
    }
    return SizedBox(height: 52, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row));
  }

  Widget _gamePicker({required bool handMode}) {
    final games = <GameType>[
      for (final s in Suit.values.reversed) GameType.suit(s),
      const GameType.grand(),
      const GameType.nullGame(),
    ];
    final ready = _picked != null && (handMode || _sel.length == 2);
    final cards = g.myHand;
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 6, runSpacing: 0, alignment: WrapAlignment.center, children: [
          for (final t in games)
            ChoiceChip(
              label: Text(t.kind == GameKind.suit ? '${t.trump!.symbol} ${t.label}' : t.label),
              selected: _picked == t,
              onSelected: (_) => setState(() => _picked = t),
            ),
        ]),
        if (_picked != null && cards.length >= 10)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Spielwert ca. ${estimateValue(handMode ? g.myHand : g.twelve, _picked!, hand: handMode)}  ·  Gebot ${g.bid}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!handMode) const Padding(padding: EdgeInsets.only(right: 8), child: Text('Wähle 2 Karten zum Drücken', style: TextStyle(color: Colors.white, fontSize: 12))),
          FilledButton(
            onPressed: ready
                ? () {
                    final t = _picked!;
                    if (handMode) {
                      final p = t;
                      _resetPick();
                      g.playHand(p);
                    } else {
                      final two = _sel.toList();
                      _resetPick();
                      g.discardAndPlay(two, t);
                    }
                  }
                : null,
            child: Text(handMode ? 'Hand spielen' : 'Drücken & Spielen'),
          ),
        ]),
      ]),
    );
  }

  Widget _hand() {
    final cards = g.myHand;
    final legal = g.legalForHuman();
    final discarding = g.phase == Phase.discard && g.declarer == 0;
    return LayoutBuilder(builder: (context, c) {
      final n = cards.length.clamp(1, 12);
      const w = 62.0;
      final step = n <= 1 ? 0.0 : ((c.maxWidth - w - 16) / (n - 1)).clamp(18.0, w * 0.9);
      final total = w + step * (n - 1);
      return SizedBox(
        height: w / kCardAspect + 20,
        child: Center(
          child: SizedBox(
            width: total,
            child: Stack(children: [
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: i * step,
                  top: 16,
                  child: Builder(builder: (_) {
                    final card = cards[i];
                    final playable = g.phase == Phase.playing && g.turn == 0 && legal.contains(card);
                    return CardView(
                      card: card,
                      width: w,
                      selected: _sel.contains(card),
                      dimmed: g.phase == Phase.playing && g.turn == 0 && !playable,
                      onTap: () {
                        if (discarding) {
                          setState(() {
                            if (!_sel.remove(card) && _sel.length < 2) _sel.add(card);
                          });
                        } else if (playable) {
                          g.playCard(card);
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
