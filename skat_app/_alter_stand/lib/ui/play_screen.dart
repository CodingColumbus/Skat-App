import 'package:flutter/material.dart';

import '../logic/game_engine.dart';
import '../logic/rules.dart';
import '../logic/scoring.dart';
import '../models/cards.dart';
import '../models/game_types.dart';
import '../state/app_state.dart';
import 'card_view.dart';

const Color _feltDark = Color(0xFF0B3D20);
const Color _feltLight = Color(0xFF166534);

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameEngine engine;
  final Set<SkatCard> selected = {};
  SkatCard? armed;
  bool _declareSheetOpen = false;
  bool _reportShown = false;
  Phase _lastPhase = Phase.idle;

  @override
  void initState() {
    super.initState();
    engine = GameEngine(settings: settings);
    engine.addListener(_onEngine);
    engine.startRound();
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    engine.dispose();
    super.dispose();
  }

  void _onEngine() {
    if (!mounted) return;
    final ph = engine.phase;
    if (ph != _lastPhase) {
      selected.clear();
      armed = null;
      _lastPhase = ph;
    }
    if (ph == Phase.declaring &&
        engine.declarer == GameEngine.humanIndex &&
        !_declareSheetOpen) {
      _declareSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _openDeclareSheet();
        _declareSheetOpen = false;
      });
    }
    if (ph == Phase.roundEnd && !_reportShown) {
      _reportShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showReport();
      });
    }
    if (ph != Phase.roundEnd) _reportShown = false;
  }

  Future<void> _openDeclareSheet() async {
    final d = await showModalBottomSheet<Declaration>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => DeclareSheet(engine: engine),
    );
    if (d != null) engine.humanDeclare(d);
  }

  Future<void> _showReport() async {
    final r = engine.report;
    if (r == null) return;
    final names = engine.names;
    final res = r.result;
    final cs = Theme.of(context).colorScheme;
    final againstText = r.declaration.type.isNull
        ? (r.endedEarly
            ? '${names[r.declarer]} musste einen Stich nehmen.'
            : '${names[r.declarer]} hat keinen Stich genommen.')
        : 'Augen: Alleinspieler ${r.declarerPoints} · Gegner ${r.defenderPoints}';
    final goHome = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          res.won ? 'Gewonnen!' : 'Verloren',
          style: TextStyle(color: res.won ? Colors.green.shade700 : cs.error),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${names[r.declarer]} spielte ${res.gameLabel}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(againstText),
              const SizedBox(height: 6),
              Text(res.formula, style: Theme.of(ctx).textTheme.bodySmall),
              if (r.skat.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Skat:'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final c in r.skat)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PlayingCardView(
                            card: c,
                            width: 38,
                            fourColor: settings.fourColorDeck),
                      ),
                  ],
                ),
              ],
              const Divider(height: 24),
              for (var p = 0; p < 3; p++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(names[p])),
                      Text(
                        '${r.deltas[p] >= 0 ? '+' : ''}${r.deltas[p]}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: r.deltas[p] > 0
                              ? Colors.green.shade700
                              : (r.deltas[p] < 0 ? cs.error : null),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text('∑ ${engine.totals[p]}',
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Beenden'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nächste Runde'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (goHome == true) {
      Navigator.of(context).pop();
    } else {
      engine.nextRound();
    }
  }

  void _onCardTap(SkatCard c) {
    final ph = engine.phase;
    if (ph == Phase.discarding) {
      setState(() {
        if (selected.contains(c)) {
          selected.remove(c);
        } else if (selected.length < 2) {
          selected.add(c);
        }
      });
    } else if (ph == Phase.playing) {
      if (!engine.legalCards.contains(c)) return;
      if (settings.singleTapPlay || armed == c) {
        setState(() => armed = null);
        engine.humanPlay(c);
      } else {
        setState(() => armed = c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _feltDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [_feltLight, _feltDark],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([engine, settings]),
            builder: (context, _) {
              return Column(
                children: [
                  _topBar(context),
                  _opponents(),
                  Expanded(child: _table()),
                  _actionBar(context),
                  _handArea(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Kopfzeile
  // ---------------------------------------------------------------------

  Widget _topBar(BuildContext context) {
    final names = engine.names;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                for (var p = 0; p < 3; p++)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${names[p]}: ${engine.totals[p]}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'new') {
                engine.newSession();
              } else if (v == 'settings') {
                Navigator.of(context).pushNamed('/settings');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('Neue Partie (Punkte zurücksetzen)')),
              PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Gegner
  // ---------------------------------------------------------------------

  Widget _opponents() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _opponentPanel(1)),
          const SizedBox(width: 8),
          Expanded(child: _opponentPanel(2)),
        ],
      ),
    );
  }

  Widget _opponentPanel(int p) {
    final names = engine.names;
    final isDeclarer = engine.declarer == p &&
        engine.phase.index >= Phase.skatChoice.index &&
        engine.phase != Phase.allPassed;
    final isTurn = engine.phase == Phase.playing &&
        engine.turn == p &&
        !engine.trickResolving;
    final winner = engine.trickResolving && engine.lastTrickWinner == p;
    final hand = engine.hands[p];
    final speech = engine.speech[p];
    final open = engine.declaration?.ouvert == true && engine.declarer == p;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(isTurn ? 90 : 55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: winner
                  ? Colors.amber
                  : (isTurn ? Colors.white70 : Colors.transparent),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: p == 1 ? Colors.indigo : Colors.deepOrange,
                child: Text(names[p][0],
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(names[p],
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      isDeclarer ? 'Alleinspieler' : engine.roleLabel(p),
                      style: TextStyle(
                          color: isDeclarer ? Colors.amber : Colors.white60,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text('${hand.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 2),
              const Icon(Icons.style, color: Colors.white54, size: 14),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: speech.isEmpty
              ? null
              : Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(speech,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
        ),
        if (open && hand.isNotEmpty)
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final c in hand)
                PlayingCardView(
                    card: c, width: 24, fourColor: settings.fourColorDeck),
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Tisch
  // ---------------------------------------------------------------------

  Widget _table() {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final cw = (w * 0.2).clamp(46.0, 74.0).toDouble();
      final ch = cw * kCardAspect;
      Offset centerFor(int p) => switch (p) {
            1 => Offset(w * 0.27, h * 0.34),
            2 => Offset(w * 0.73, h * 0.34),
            _ => Offset(w * 0.5, h * 0.68),
          };

      final children = <Widget>[];

      final showSkat = engine.phase == Phase.bidding ||
          engine.phase == Phase.forehandChoice ||
          engine.phase == Phase.skatChoice;
      if (showSkat) {
        children.add(Positioned(
          left: w / 2 - cw * 0.85,
          top: h * 0.05,
          child: Row(
            children: [
              PlayingCardView(width: cw * 0.75),
              const SizedBox(width: 4),
              PlayingCardView(width: cw * 0.75),
            ],
          ),
        ));
        children.add(Positioned(
          left: 0,
          right: 0,
          top: h * 0.05 + cw * 0.75 * kCardAspect + 4,
          child: const Center(
            child: Text('Skat',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ));
      }

      for (final t in engine.trick) {
        final c = centerFor(t.player);
        final isWinner = engine.trickResolving && engine.lastTrickWinner == t.player;
        children.add(Positioned(
          left: c.dx - cw / 2,
          top: c.dy - ch / 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cw * 0.1),
              boxShadow: isWinner
                  ? [
                      BoxShadow(
                          color: Colors.amber.withAlpha(200),
                          blurRadius: 14,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: PlayingCardView(
                card: t.card, width: cw, fourColor: settings.fourColorDeck),
          ),
        ));
      }

      children.add(Positioned(
        left: 12,
        right: 12,
        bottom: 4,
        child: _statusText(),
      ));

      return Stack(children: children);
    });
  }

  Widget _statusText() {
    String text = engine.message;
    final d = engine.declaration;
    if (engine.phase == Phase.playing && d != null) {
      final who = engine.names[engine.declarer];
      final dTricks = engine.trickCounts[engine.declarer];
      text = '$who: ${d.label} · Reizwert ${engine.bidValue}\n'
          'Stiche – Alleinspieler $dTricks · Gegner ${_defenderTricks()}';
    } else if (engine.phase == Phase.bidding) {
      text = 'Du bist ${engine.roleLabel(0)}';
    } else if (engine.phase == Phase.forehandChoice) {
      text = 'Niemand hat gereizt.';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
  }

  int _defenderTricks() {
    var sum = 0;
    for (var p = 0; p < 3; p++) {
      if (p != engine.declarer) sum += engine.trickCounts[p];
    }
    return sum;
  }

  // ---------------------------------------------------------------------
  // Aktionsleiste
  // ---------------------------------------------------------------------

  Widget _actionBar(BuildContext context) {
    final names = engine.names;
    Widget content;
    switch (engine.phase) {
      case Phase.bidding:
        if (engine.humanMustBid) {
          if (engine.callerToAct) {
            final n = engine.nextBidValue;
            content = _bar(
              'Du bist dran – reizen oder weg?',
              [
                if (n > 0)
                  FilledButton(
                      onPressed: engine.humanBid, child: Text('Reizen $n')),
                OutlinedButton(
                    style: _outlineLight,
                    onPressed: engine.humanPassBid,
                    child: const Text('Weg')),
              ],
            );
          } else {
            content = _bar(
              '${names[engine.caller]} reizt ${engine.currentBid} – gehst du mit?',
              [
                FilledButton(
                    onPressed: engine.humanAccept,
                    child: Text('Ja, ${engine.currentBid}')),
                OutlinedButton(
                    style: _outlineLight,
                    onPressed: engine.humanPassBid,
                    child: const Text('Weg')),
              ],
            );
          }
        } else {
          content = _bar('${names[engine.actingBidder]} überlegt …', const []);
        }
      case Phase.forehandChoice:
        if (engine.forehand == GameEngine.humanIndex) {
          content = _bar(
            'Niemand hat gereizt. Spiel übernehmen (Reizwert 18)?',
            [
              FilledButton(
                  onPressed: engine.forehandTakeOver,
                  child: const Text('Spielen')),
              OutlinedButton(
                  style: _outlineLight,
                  onPressed: engine.forehandPass,
                  child: const Text('Einpassen')),
            ],
          );
        } else {
          content = _bar('${names[engine.forehand]} überlegt …', const []);
        }
      case Phase.allPassed:
        content = _bar(engine.message, [
          FilledButton(
              onPressed: engine.nextRound, child: const Text('Neu geben')),
        ]);
      case Phase.skatChoice:
        if (engine.declarer == GameEngine.humanIndex) {
          content = _bar(
            'Du spielst (Reizwert ${engine.bidValue}). Skat aufnehmen?',
            [
              FilledButton(
                  onPressed: engine.humanTakeSkat,
                  child: const Text('Skat aufnehmen')),
              OutlinedButton(
                  style: _outlineLight,
                  onPressed: engine.humanPlayHand,
                  child: const Text('Hand spielen')),
            ],
          );
        } else {
          content = _bar(engine.message, const []);
        }
      case Phase.discarding:
        content = _bar(
          'Wähle 2 Karten zum Drücken (${selected.length}/2)',
          [
            FilledButton(
              onPressed: selected.length == 2
                  ? () => engine.humanDiscard(selected.toList())
                  : null,
              child: const Text('Drücken'),
            ),
          ],
        );
      case Phase.declaring:
        if (engine.declarer == GameEngine.humanIndex) {
          content = _bar('Sage dein Spiel an', [
            FilledButton(
              onPressed: () async {
                if (_declareSheetOpen) return;
                _declareSheetOpen = true;
                await _openDeclareSheet();
                _declareSheetOpen = false;
              },
              child: const Text('Spiel ansagen'),
            ),
          ]);
        } else {
          content = _bar(engine.message, const []);
        }
      case Phase.playing:
        if (engine.trickResolving) {
          content = _bar('Stich für ${names[engine.lastTrickWinner]}', const []);
        } else if (engine.turn == GameEngine.humanIndex) {
          content = _bar(
              settings.singleTapPlay
                  ? 'Du bist dran – Karte antippen'
                  : 'Du bist dran – Karte antippen, nochmal tippen zum Spielen',
              const []);
        } else {
          content = _bar('${names[engine.turn]} spielt …', const []);
        }
      case Phase.roundEnd:
      case Phase.idle:
        content = _bar('', const []);
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey('${engine.phase}-${engine.actingBidder}-${engine.callerToAct}'),
          child: content,
        ),
      ),
    );
  }

  ButtonStyle get _outlineLight => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white70),
      );

  Widget _bar(String text, List<Widget> buttons) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        if (buttons.isNotEmpty) const SizedBox(height: 8),
        if (buttons.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: buttons,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Eigene Hand
  // ---------------------------------------------------------------------

  Widget _handArea() {
    final hand = engine.hands[GameEngine.humanIndex];
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final n = hand.length;
      final cw = (w / 5.4).clamp(48.0, 74.0).toDouble();
      final ch = cw * kCardAspect;
      final legal = engine.legalCards;
      final playing = engine.phase == Phase.playing &&
          engine.turn == GameEngine.humanIndex &&
          !engine.trickResolving;

      double step = n <= 1 ? 0 : (w - cw - 16) / (n - 1);
      if (step > cw * 0.7) step = cw * 0.7;
      final total = n <= 1 ? cw : cw + step * (n - 1);
      final startX = (w - total) / 2;

      final cards = <Widget>[];
      for (var i = 0; i < n; i++) {
        final c = hand[i];
        final raised = selected.contains(c) || armed == c;
        final dim = playing && !legal.contains(c);
        cards.add(Positioned(
          left: startX + step * i,
          bottom: raised ? 16 : 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onCardTap(c),
            child: PlayingCardView(
                card: c,
                width: cw,
                dimmed: dim,
                fourColor: settings.fourColorDeck),
          ),
        ));
      }

      final isOuvert = engine.declaration?.ouvert == true &&
          engine.declarer == GameEngine.humanIndex;
      return SizedBox(
        height: ch + 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ...cards,
            if (isOuvert)
              const Positioned(
                right: 8,
                top: 0,
                child: Text('offen gespielt',
                    style: TextStyle(color: Colors.amber, fontSize: 11)),
              ),
          ],
        ),
      );
    });
  }
}

// -----------------------------------------------------------------------
// Spielansage
// -----------------------------------------------------------------------

class DeclareSheet extends StatefulWidget {
  const DeclareSheet({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<DeclareSheet> createState() => _DeclareSheetState();
}

class _DeclareSheetState extends State<DeclareSheet> {
  GameType type = GameType.clubs;
  bool ouvert = false;
  bool schneiderAnn = false;
  bool schwarzAnn = false;

  bool get isHand => !widget.engine.skatTaken;

  @override
  void initState() {
    super.initState();
    // Vorschlag: bestes Spiel anhand der aktuellen Karten.
    final hand = widget.engine.hands[GameEngine.humanIndex];
    var best = GameType.clubs;
    var bestScore = -1.0;
    for (final t in GameType.values) {
      var score = 0.0;
      final sp = countSpitzen(hand, t);
      score = sp.count.toDouble() * (sp.withJacks ? 1 : 0.4);
      if (t.isSuit) {
        score += hand.where((c) => !c.isJack && c.suit == t.trumpSuit).length * 0.6;
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    type = best;
  }

  /// Zu zählende Karten für die Spitzen (Hand: nur die zehn Handkarten).
  List<SkatCard> get _spitzenCards {
    final e = widget.engine;
    final hand = e.hands[GameEngine.humanIndex];
    if (isHand) return hand;
    return [...hand, ...e.skat];
  }

  int get _minValue {
    if (type.isNull) {
      return nullValue(hand: isHand, ouvert: ouvert);
    }
    final sp = countSpitzen(_spitzenCards, type);
    var m = sp.count + 1;
    if (isHand) m++;
    if (schneiderAnn) m += 1;
    if (schwarzAnn) m += 1;
    return type.baseValue * m;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final sp = type.isNull ? null : countSpitzen(_spitzenCards, type);
    final bid = e.bidValue;
    final risky = _minValue < bid;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isHand ? 'Handspiel ansagen' : 'Spiel ansagen',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Reizwert: $bid',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in GameType.values)
                  ChoiceChip(
                    selected: type == t,
                    onSelected: (_) => setState(() {
                      type = t;
                      if (!t.isNull) ouvert = false;
                    }),
                    avatar: t.isSuit
                        ? SuitIcon(t.trumpSuit!, size: 18, color: suitColor(t.trumpSuit!, false))
                        : null,
                    label: Text(t.nameDe),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (sp != null)
              Text(
                '${sp.withJacks ? 'Mit' : 'Ohne'} ${sp.count}, spielt ${sp.count + 1}'
                '${isHand ? ' (der Skat zählt zusätzlich mit)' : ''}',
              ),
            if (type.isNull)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ouvert (Karten offen auf den Tisch)'),
                value: ouvert,
                onChanged: (v) => setState(() => ouvert = v),
              ),
            if (isHand && !type.isNull) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schneider angesagt'),
                value: schneiderAnn,
                onChanged: (v) => setState(() {
                  schneiderAnn = v;
                  if (!v) schwarzAnn = false;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schwarz angesagt'),
                value: schwarzAnn,
                onChanged: (v) => setState(() {
                  schwarzAnn = v;
                  if (v) schneiderAnn = true;
                }),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Mindestwert dieses Spiels: $_minValue',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (risky)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Achtung: Der Wert liegt unter dem Reizwert $bid. Ohne Schneider/'
                  'Schwarz (mehr Multiplikatoren) wäre das Spiel überreizt und verloren.',
                  style: TextStyle(color: cs.error),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  Declaration(
                    type: type,
                    hand: isHand,
                    ouvert: type.isNull && ouvert,
                    schneiderAnnounced: isHand && !type.isNull && schneiderAnn,
                    schwarzAnnounced: isHand && !type.isNull && schwarzAnn,
                  ),
                ),
                child: const Text('Spiel beginnen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
