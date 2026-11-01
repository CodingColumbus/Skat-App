import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../logic/game.dart';
import '../logic/view.dart';
import 'controller.dart';

const int kPort = 47474;
const int kDiscoveryPort = 47475;
const _botNames = ['Anna', 'Max', 'Lena'];

class PeerConn {
  PeerConn(this.socket);
  final Socket socket;
  String name = '?';
  int? seat;

  void send(Map<String, dynamic> m) {
    try {
      socket.write('${jsonEncode(m)}\n');
    } catch (_) {}
  }

  void listen(void Function(Map<String, dynamic>) onMsg, void Function() onDone) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            try {
              onMsg(jsonDecode(line) as Map<String, dynamic>);
            } catch (_) {}
          },
          onDone: onDone,
          onError: (_) => onDone(),
          cancelOnError: true,
        );
  }

  void close() {
    try {
      socket.destroy();
    } catch (_) {}
  }
}

Future<List<String>> localAddresses() async {
  try {
    final l = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [for (final i in l) for (final a in i.addresses) if (!a.isLoopback) a.address];
  } catch (_) {
    return [];
  }
}

/// Der Host eines Tisches: nimmt Mitspieler an und betreibt später die Engine.
class HostServer extends ChangeNotifier {
  HostServer(this.hostName);
  final String hostName;
  final List<PeerConn> clients = [];
  ServerSocket? _server;
  RawDatagramSocket? _beacon;
  Timer? _beaconTimer;
  SkatGame? game;
  bool started = false;
  List<String> addresses = [];
  String? error;

  List<String> get playerNames => [hostName, ...clients.map((c) => c.name)];

  Future<void> start() async {
    addresses = await localAddresses();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, kPort, shared: true);
      _server!.listen(_onClient, onError: (_) {});
    } catch (e) {
      final perm = e.toString().contains('not permitted')
          ? ' (Der App fehlt die Netzwerk-Berechtigung. Bitte die neueste APK installieren.)'
          : '';
      error = 'Tisch konnte nicht geöffnet werden: $e$perm';
      notifyListeners();
      return;
    }
    try {
      _beacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _beacon!.broadcastEnabled = true;
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _beaconSend());
      _beaconSend();
    } catch (_) {
      // Ohne Broadcast kann man trotzdem per IP beitreten.
    }
    notifyListeners();
  }

  void _beaconSend() {
    final b = _beacon;
    if (b == null || started) return;
    final data = utf8.encode(jsonEncode({'app': 'skat', 'name': hostName, 'port': kPort, 'n': playerNames.length}));
    final targets = <String>{'255.255.255.255'};
    for (final a in addresses) {
      final p = a.split('.');
      if (p.length == 4) targets.add('${p[0]}.${p[1]}.${p[2]}.255');
    }
    for (final t in targets) {
      try {
        b.send(data, InternetAddress(t), kDiscoveryPort);
      } catch (_) {}
    }
  }

  void _onClient(Socket s) {
    final conn = PeerConn(s);
    var joined = false;
    conn.listen((m) {
      switch (m['t']) {
        case 'join':
          if (started || clients.length >= 3) {
            conn.send({'t': 'full'});
            conn.close();
            return;
          }
          var name = (m['name'] as String? ?? 'Gast').trim();
          if (name.isEmpty) name = 'Gast';
          while (playerNames.contains(name)) {
            name = '$name*';
          }
          conn.name = name;
          clients.add(conn);
          joined = true;
          _broadcastLobby();
        case 'act':
          final g = game;
          if (g != null && conn.seat != null) {
            applyAction(g, conn.seat!, (m['x'] as Map).cast<String, dynamic>());
          }
      }
    }, () {
      if (!joined) return;
      clients.remove(conn);
      final g = game;
      if (g != null && conn.seat != null) {
        g.replaceWithBot(conn.seat!);
      } else {
        _broadcastLobby();
      }
      notifyListeners();
    });
  }

  void _broadcastLobby() {
    final msg = {'t': 'lobby', 'players': playerNames};
    for (final c in clients) {
      c.send(msg);
    }
    notifyListeners();
  }

  /// Startet das Spiel; fehlende Spieler werden mit Bots aufgefüllt (3 Sitze, bei 4 Menschen 4 Sitze).
  HostController startGame({required Duration botDelay, required Duration trickDelay}) {
    final humans = playerNames;
    final seats = <SeatInfo>[for (final n in humans) SeatInfo(n, false)];
    var b = 0;
    while (seats.length < 3) {
      seats.add(SeatInfo(_botNames[b++ % _botNames.length], true));
    }
    final g = SkatGame(seats: seats, botDelay: botDelay, trickDelay: trickDelay);
    game = g;
    started = true;
    for (var i = 0; i < clients.length; i++) {
      clients[i].seat = i + 1;
      clients[i].send({'t': 'start', 'seat': i + 1});
    }
    g.addListener(_broadcastViews);
    final hc = HostController(g, this);
    _broadcastViews();
    return hc;
  }

  void _broadcastViews() {
    final g = game;
    if (g == null) return;
    for (final c in clients) {
      if (c.seat != null) c.send({'t': 'view', 'v': g.viewFor(c.seat!).toJson()});
    }
  }

  void stop() {
    _beaconTimer?.cancel();
    _beacon?.close();
    _server?.close();
    for (final c in clients) {
      c.send({'t': 'bye'});
      c.close();
    }
    clients.clear();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class HostController extends LocalController {
  HostController(SkatGame game, this.server) : super(game, fixedSeat: 0);
  final HostServer server;
  @override
  bool get isOnline => true;
  @override
  void dispose() {
    server.stop();
    super.dispose();
  }
}

class FoundHost {
  FoundHost(this.ip, this.name, this.port, this.players, this.seen);
  final String ip;
  final String name;
  final int port;
  int players;
  DateTime seen;
}

/// Sucht Tische im WLAN per UDP-Broadcast.
class HostFinder extends ChangeNotifier {
  RawDatagramSocket? _sock;
  Timer? _prune;
  final Map<String, FoundHost> _hosts = {};
  List<FoundHost> get hosts => _hosts.values.toList();

  Future<void> start() async {
    try {
      _sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kDiscoveryPort, reuseAddress: true);
      _sock!.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = _sock!.receive();
        if (d == null) return;
        try {
          final m = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
          if (m['app'] != 'skat') return;
          _hosts[d.address.address] =
              FoundHost(d.address.address, m['name'] as String, m['port'] as int, m['n'] as int, DateTime.now());
          notifyListeners();
        } catch (_) {}
      });
    } catch (_) {}
    _prune = Timer.periodic(const Duration(seconds: 2), (_) {
      final before = _hosts.length;
      _hosts.removeWhere((_, h) => DateTime.now().difference(h.seen) > const Duration(seconds: 6));
      if (_hosts.length != before) notifyListeners();
    });
  }

  @override
  void dispose() {
    _prune?.cancel();
    _sock?.close();
    super.dispose();
  }
}

/// Spieler auf einem anderen Handy.
class ClientController extends GameController {
  PeerConn? _conn;
  GameView? _view;
  List<String> lobbyPlayers = [];
  bool started = false;
  String? _status;
  bool failed = false;

  @override
  GameView? get view => _view;
  @override
  bool get isOnline => true;
  @override
  bool get canResetTotals => false;
  @override
  String? get status => _status;

  Future<bool> connect(String ip, int port, String name) async {
    try {
      final s = await Socket.connect(ip, port, timeout: const Duration(seconds: 6));
      s.setOption(SocketOption.tcpNoDelay, true);
      final c = PeerConn(s);
      _conn = c;
      c.listen(_onMsg, () {
        if (!failed) {
          _status = 'Verbindung zum Host getrennt.';
          failed = true;
          notifyListeners();
        }
      });
      c.send({'t': 'join', 'name': name});
      return true;
    } catch (e) {
      _status = 'Verbindung fehlgeschlagen. Sind beide Handys im selben WLAN?';
      failed = true;
      notifyListeners();
      return false;
    }
  }

  void _onMsg(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'lobby':
        lobbyPlayers = (m['players'] as List).cast<String>();
      case 'start':
        started = true;
      case 'view':
        _view = GameView.fromJson((m['v'] as Map).cast<String, dynamic>());
      case 'full':
        _status = 'Der Tisch ist voll oder das Spiel läuft schon.';
        failed = true;
      case 'bye':
        _status = 'Der Host hat den Tisch geschlossen.';
        failed = true;
    }
    notifyListeners();
  }

  @override
  void send(Map<String, dynamic> action) => _conn?.send({'t': 'act', 'x': action});

  @override
  void dispose() {
    _conn?.close();
    super.dispose();
  }
}
