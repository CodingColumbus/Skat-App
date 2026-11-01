import 'dart:async';
import 'package:flutter/material.dart';
import '../net/net.dart';
import '../state/settings.dart';
import 'game_screen.dart';

/// Einstieg: Tisch eröffnen oder beitreten (WLAN / Hotspot).
class OnlineMenuScreen extends StatelessWidget {
  const OnlineMenuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehrspieler (WLAN)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text(
            'Alle Handys müssen im selben WLAN sein oder im Hotspot eines Mitspielers. '
            'Android und iPhone können zusammen spielen. Fehlende Spieler füllt die App mit Bots auf.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HostLobbyScreen())),
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Tisch eröffnen'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinScreen())),
            icon: const Icon(Icons.login),
            label: const Text('Tisch beitreten'),
          ),
        ]),
      ),
    );
  }
}

class HostLobbyScreen extends StatefulWidget {
  const HostLobbyScreen({super.key});
  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  HostServer? server;
  bool handedOver = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (server == null) {
      final s = SettingsScope.of(context);
      server = HostServer(s.playerName)..start();
    }
  }

  @override
  void dispose() {
    if (!handedOver) server?.dispose();
    super.dispose();
  }

  void _start() {
    final s = SettingsScope.of(context);
    final hc = server!.startGame(botDelay: s.botDelay, trickDelay: s.trickDelay);
    handedOver = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(controller: hc)));
  }

  @override
  Widget build(BuildContext context) {
    final sv = server!;
    return Scaffold(
      appBar: AppBar(title: const Text('Dein Tisch')),
      body: ListenableBuilder(
        listenable: sv,
        builder: (context, _) {
          final names = sv.playerNames;
          final seats = names.length < 3 ? 3 : names.length;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (sv.error != null) Text(sv.error!, style: const TextStyle(color: Colors.red)),
            const Text('Mitspieler sehen deinen Tisch automatisch in der Liste „Tisch beitreten“. Alternativ geben sie diese Adresse ein:'),
            const SizedBox(height: 8),
            for (final a in sv.addresses) SelectableText(a, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            if (sv.addresses.isEmpty) const Text('Keine WLAN-Adresse gefunden. Bist du verbunden?'),
            const SizedBox(height: 20),
            Text('Am Tisch (${names.length}):', style: const TextStyle(fontWeight: FontWeight.w600)),
            for (var i = 0; i < names.length; i++)
              ListTile(dense: true, leading: Icon(i == 0 ? Icons.star : Icons.person), title: Text(names[i] + (i == 0 ? ' (Host)' : ''))),
            if (seats > names.length)
              ListTile(
                dense: true,
                leading: const Icon(Icons.smart_toy),
                title: Text('${seats - names.length} Bot${seats - names.length > 1 ? 's' : ''} füllen auf'),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: sv.error == null ? _start : null, icon: const Icon(Icons.play_arrow), label: const Text('Spiel starten')),
          ]);
        },
      ),
    );
  }
}

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final finder = HostFinder();
  final ip = TextEditingController();
  ClientController? client;
  bool connecting = false;
  bool handedOver = false;

  @override
  void initState() {
    super.initState();
    finder.start();
  }

  @override
  void dispose() {
    finder.dispose();
    ip.dispose();
    if (!handedOver) client?.dispose();
    super.dispose();
  }

  Future<void> _join(String address, int port) async {
    final name = SettingsScope.of(context).playerName;
    final cc = ClientController();
    setState(() {
      connecting = true;
      client = cc;
    });
    final ok = await cc.connect(address, port, name);
    if (!mounted) return;
    setState(() => connecting = false);
    if (!ok) return;
    cc.addListener(_onClient);
  }

  void _onClient() {
    final cc = client!;
    if (cc.started && cc.view != null && !handedOver) {
      handedOver = true;
      cc.removeListener(_onClient);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(controller: cc)));
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = client;
    if (cc != null && !cc.failed && !connecting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Warteraum')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Verbunden. Der Host startet gleich das Spiel.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final n in cc.lobbyPlayers) ListTile(dense: true, leading: const Icon(Icons.person), title: Text(n)),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tisch beitreten')),
      body: ListenableBuilder(
        listenable: finder,
        builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
          if (cc?.status != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(cc!.status!, style: const TextStyle(color: Colors.red))),
          if (connecting) const LinearProgressIndicator(),
          const Text('Gefundene Tische', style: TextStyle(fontWeight: FontWeight.w600)),
          if (finder.hosts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Suche … (der Host muss „Tisch eröffnen“ gewählt haben)')),
          for (final h in finder.hosts)
            ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: Text(h.name),
              subtitle: Text('${h.ip} · ${h.players} Spieler'),
              onTap: connecting ? null : () => _join(h.ip, h.port),
            ),
          const Divider(height: 32),
          const Text('Oder Adresse des Hosts eingeben', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: ip,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'z. B. 192.168.0.12', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: connecting ? null : () => _join(ip.text.trim(), kPort), child: const Text('Verbinden')),
        ]),
      ),
    );
  }
}
