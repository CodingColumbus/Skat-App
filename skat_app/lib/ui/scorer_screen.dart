import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/cards.dart';
import '../logic/rules.dart';
import '../logic/scoring.dart';

class ScoreEntry {
  final String desc;
  final List<int> deltas;
  ScoreEntry(this.desc, this.deltas);
  Map<String, dynamic> toJson() => {'d': desc, 'p': deltas};
  factory ScoreEntry.fromJson(Map<String, dynamic> j) =>
      ScoreEntry(j['d'] as String, (j['p'] as List).map((e) => e as int).toList());
}

class ScorerScreen extends StatefulWidget {
  const ScorerScreen({super.key});
  @override
  State<ScorerScreen> createState() => _ScorerScreenState();
}

class _ScorerScreenState extends State<ScorerScreen> {
  List<String> names = ['Spieler 1', 'Spieler 2', 'Spieler 3'];
  List<ScoreEntry> entries = [];
  bool seeger = false; // Seeger-Fabian-Wertung
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('sheet');
      if (s != null) {
        final j = jsonDecode(s) as Map<String, dynamic>;
        names = (j['names'] as List).cast<String>();
        entries = (j['entries'] as List).map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>)).toList();
        seeger = j['seeger'] as bool? ?? false;
      }
    } catch (_) {}
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('sheet', jsonEncode({
        'names': names,
        'entries': entries.map((e) => e.toJson()).toList(),
        'seeger': seeger,
      }));
    } catch (_) {}
  }

  int total(int i) => entries.fold(0, (a, e) => a + (i < e.deltas.length ? e.deltas[i] : 0));

  void _commit(VoidCallback f) {
    setState(f);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punkte notieren'),
        actions: [
          IconButton(icon: const Icon(Icons.people), tooltip: 'Spieler', onPressed: _editPlayers),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') {
                _commit(() => entries.clear());
              } else if (v == 'seeger') {
                _commit(() => seeger = !seeger);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'seeger', checked: seeger, child: const Text('Seeger-Fabian-Wertung')),
              const PopupMenuItem(value: 'reset', child: Text('Liste leeren')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Spiel eintragen'),
      ),
      body: Column(children: [
        _header(),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('Noch keine Spiele eingetragen.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[entries.length - 1 - i];
                    final idx = entries.length - 1 - i;
                    return Dismissible(
                      key: ValueKey('$idx-${e.desc}-${e.deltas}'),
                      background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16), child: const Icon(Icons.delete, color: Colors.white)),
                      secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (_) => _commit(() => entries.removeAt(idx)),
                      child: ListTile(
                        dense: true,
                        title: Text(e.desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('Spiel ${idx + 1}'),
                        trailing: SizedBox(
                          width: 40.0 * names.length + 20,
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            for (var p = 0; p < names.length; p++)
                              SizedBox(
                                width: 40,
                                child: Text(p < e.deltas.length ? '${e.deltas[p]}' : '',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: p < e.deltas.length && e.deltas[p] < 0 ? Colors.red : null)),
                              ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _header() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(children: [
        for (var i = 0; i < names.length; i++)
          Expanded(
            child: Column(children: [
              Text(names[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${total(i)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: total(i) < 0 ? Colors.red : null)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _editPlayers() async {
    final ctrls = [for (final n in names) TextEditingController(text: n)];
    var count = names.length;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        while (ctrls.length < count) {
          ctrls.add(TextEditingController(text: 'Spieler ${ctrls.length + 1}'));
        }
        return AlertDialog(
          title: const Text('Spieler'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 3, label: Text('3')), ButtonSegment(value: 4, label: Text('4'))],
                selected: {count},
                onSelectionChanged: (s) => setS(() => count = s.first),
              ),
              for (var i = 0; i < count; i++)
                TextField(controller: ctrls[i], decoration: InputDecoration(labelText: 'Name ${i + 1}')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final newNames = [
                  for (var i = 0; i < count; i++) ctrls[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctrls[i].text.trim()
                ];
                _commit(() {
                  if (newNames.length != names.length) entries.clear();
                  names = newNames;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _addEntry() async {
    final e = await showModalBottomSheet<ScoreEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EntrySheet(names: names, seeger: seeger, round: entries.length),
    );
    if (e != null) _commit(() => entries.add(e));
  }
}

class _EntrySheet extends StatefulWidget {
  final List<String> names;
  final bool seeger;
  final int round;
  const _EntrySheet({required this.names, required this.seeger, required this.round});
  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  bool manual = false;
  int declarer = 0;
  late int sitsOut = widget.names.length == 4 ? widget.round % 4 : -1;
  GameType game = const GameType.suit(Suit.kreuz);
  bool mit = true;
  int spitzen = 1;
  bool hand = false, ouvert = false;
  bool schneider = false, schwarz = false;
  bool schneiderAn = false, schwarzAn = false;
  bool won = true;
  final bid = TextEditingController();
  late final List<TextEditingController> manualCtrls = [for (final _ in widget.names) TextEditingController(text: '0')];

  ScoreInput get input => ScoreInput(
        game: game,
        mit: mit,
        spitzen: spitzen,
        hand: hand,
        ouvert: ouvert,
        schneider: schneider,
        schwarz: schwarz,
        schneiderAnsage: schneiderAn,
        schwarzAnsage: schwarzAn,
        won: won,
        bid: int.tryParse(bid.text) ?? 0,
      );

  List<int> deltas() {
    final n = widget.names.length;
    final d = List.filled(n, 0);
    if (manual) {
      for (var i = 0; i < n; i++) {
        d[i] = int.tryParse(manualCtrls[i].text.trim()) ?? 0;
      }
      return d;
    }
    final v = gameValue(input);
    if (widget.seeger) {
      final base = scoreFor(input);
      d[declarer] = won && base > 0 ? 50 + v : -(50 + (base < 0 ? -base : 2 * v));
      if (!(won && base > 0)) {
        for (var i = 0; i < n; i++) {
          if (i != declarer && i != sitsOut) d[i] = 40;
        }
      }
    } else {
      d[declarer] = scoreFor(input);
    }
    return d;
  }

  String describe() {
    if (manual) return 'Manuell';
    final b = StringBuffer(widget.names[declarer]);
    b.write(': ${game.label}');
    if (!game.isNull) b.write(mit ? ' mit $spitzen' : ' ohne $spitzen');
    if (hand) b.write(' Hand');
    if (ouvert) b.write(' Ouvert');
    if (schneiderAn) {
      b.write(' Schneider angesagt');
    } else if (schneider) {
      b.write(' Schneider');
    }
    if (schwarzAn) {
      b.write(' Schwarz angesagt');
    } else if (schwarz) {
      b.write(' Schwarz');
    }
    b.write(won ? ' (gewonnen)' : ' (verloren)');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final d = deltas();
    final games = <GameType>[
      for (final s in Suit.values.reversed) GameType.suit(s),
      const GameType.grand(),
      const GameType.nullGame(),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Automatisch'), icon: Icon(Icons.calculate)),
              ButtonSegment(value: true, label: Text('Manuell'), icon: Icon(Icons.edit)),
            ],
            selected: {manual},
            onSelectionChanged: (s) => setState(() => manual = s.first),
          ),
          const SizedBox(height: 12),
          if (manual) ...[
            for (var i = 0; i < names.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: manualCtrls[i],
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  decoration: InputDecoration(labelText: 'Punkte ${names[i]}', border: const OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ] else ...[
            const Text('Alleinspieler', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < names.length; i++)
                if (i != sitsOut)
                  ChoiceChip(label: Text(names[i]), selected: declarer == i, onSelected: (_) => setState(() => declarer = i)),
            ]),
            if (names.length == 4) ...[
              const SizedBox(height: 8),
              const Text('Geber (setzt aus)', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < 4; i++)
                  ChoiceChip(
                    label: Text(names[i]),
                    selected: sitsOut == i,
                    onSelected: (_) => setState(() {
                      sitsOut = i;
                      if (declarer == i) declarer = (i + 1) % 4;
                    }),
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            const Text('Spiel', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: [
              for (final t in games)
                ChoiceChip(
                  label: Text(t.kind == GameKind.suit ? '${t.trump!.symbol} ${t.label}' : t.label),
                  selected: game == t,
                  onSelected: (_) => setState(() {
                    game = t;
                    if (t.isNull) {
                      schneider = schwarz = schneiderAn = schwarzAn = false;
                    }
                  }),
                ),
            ]),
            if (!game.isNull) ...[
              const SizedBox(height: 12),
              Row(children: [
                SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: true, label: Text('Mit')), ButtonSegment(value: false, label: Text('Ohne'))],
                  selected: {mit},
                  onSelectionChanged: (s) => setState(() => mit = s.first),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: spitzen > 1 ? () => setState(() => spitzen--) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$spitzen', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: spitzen < 11 ? () => setState(() => spitzen++) : null, icon: const Icon(Icons.add_circle_outline)),
              ]),
            ],
            Wrap(spacing: 8, children: [
              FilterChip(label: const Text('Hand'), selected: hand, onSelected: (v) => setState(() => hand = v)),
              FilterChip(label: const Text('Ouvert'), selected: ouvert, onSelected: (v) => setState(() => ouvert = v)),
              if (!game.isNull) ...[
                FilterChip(label: const Text('Schneider'), selected: schneider, onSelected: (v) => setState(() => schneider = v)),
                FilterChip(label: const Text('Schneider angesagt'), selected: schneiderAn, onSelected: (v) => setState(() => schneiderAn = v)),
                FilterChip(label: const Text('Schwarz'), selected: schwarz, onSelected: (v) => setState(() => schwarz = v)),
                FilterChip(label: const Text('Schwarz angesagt'), selected: schwarzAn, onSelected: (v) => setState(() => schwarzAn = v)),
              ],
            ]),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Gewonnen')), ButtonSegment(value: false, label: Text('Verloren'))],
              selected: {won},
              onSelectionChanged: (s) => setState(() => won = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gereizter Wert (optional, für Überreizen)', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                for (var i = 0; i < names.length; i++)
                  Expanded(
                    child: Column(children: [
                      Text(names[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      Text('${d[i] > 0 ? '+' : ''}${d[i]}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: d[i] < 0 ? Colors.red : null)),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, ScoreEntry(describe(), d)),
            icon: const Icon(Icons.check),
            label: const Text('Eintragen'),
          ),
        ]),
      ),
    );
  }
}
