import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _sections = <(String, String)>[
    ('Ziel des Spiels',
        'Skat wird mit 32 Karten von drei Spielern gespielt. Einer wird Alleinspieler und spielt gegen die beiden anderen (die Gegenspieler). '
            'Der Alleinspieler gewinnt, wenn er mindestens 61 von 120 Augen erreicht. Beim Nullspiel gewinnt er, wenn er keinen einzigen Stich bekommt.\n\n'
            'Bei vier Spielern teilt jeder Geber aus und setzt in dieser Runde aus. Gespielt wird immer zu dritt.'),
    ('Kartenwerte (Augen)',
        'Ass = 11\nZehn = 10\nKönig = 4\nDame (Ober) = 3\nBube (Unter) = 2\nNeun, Acht, Sieben = 0\n\n'
            'Insgesamt gibt es 120 Augen.'),
    ('Trumpf und Rangfolge',
        'Die vier Buben (Unter) sind immer die höchsten Trümpfe: Kreuz (Eichel) > Pik (Laub) > Herz > Karo (Schellen).\n\n'
            'Danach folgt die Trumpffarbe: Ass, Zehn, König, Dame (Ober), Neun, Acht, Sieben.\n\n'
            'In den anderen Farben gilt: Ass, Zehn, König, Dame, Neun, Acht, Sieben. Die Buben gehören nie zur Farbe, sondern sind Trumpf.\n\n'
            'Grand: Nur die vier Buben sind Trumpf.\n\n'
            'Null: Es gibt keine Trümpfe. Reihenfolge: Ass, König, Dame, Bube, Zehn, Neun, Acht, Sieben.'),
    ('Geben und Reizen',
        'Jeder bekommt zehn Karten, zwei Karten liegen als Skat verdeckt in der Mitte.\n\n'
            'Mittelhand sagt einen Wert an, Vorhand antwortet mit „Halten“ oder „Passen“. Der Sieger dieses Duells wird von Hinterhand überboten. '
            'Wer zuletzt hält, wird Alleinspieler. Gereizt wird mit den Spielwerten (18, 20, 22, 23, 24, 27, 30, 33, 35, 36 …).\n\n'
            'Passen alle, muss Vorhand entweder mit 18 spielen oder einwerfen (neu geben).'),
    ('Skat, Hand und Drücken',
        'Der Alleinspieler darf den Skat aufnehmen, muss danach zwei beliebige Karten wieder ablegen (drücken) und sagt sein Spiel an. '
            'Die gedrückten Karten zählen am Ende zu seinen Augen.\n\n'
            'Wer den Skat liegen lässt, spielt „Hand“. Das bringt einen höheren Spielwert.'),
    ('Spielarten und Grundwerte',
        'Karo (Schellen): 9\nHerz: 10\nPik (Laub): 11\nKreuz (Eichel): 12\nGrand: 24\nNull: 23, Null Hand 35, Null Ouvert 46, Ouvert Hand 59'),
    ('Spielwert (Farbe und Grand)',
        'Spielwert = Grundwert × Multiplikator.\n\n'
            'Der Multiplikator besteht aus:\n• „Mit“ oder „Ohne“ so vielen Buben in Folge (ab Kreuz-Bube), plus 1 für das Spiel\n'
            '• +1 für Hand\n• +1 für Schneider (Gegner unter 31 Augen oder Alleinspieler ab 90 Augen)\n'
            '• +1 für Schwarz (eine Seite macht keinen Stich)\n• +1 für Ouvert\n• Angesagtes Schneider/Schwarz bringt je eine zusätzliche Stufe.\n\n'
            'Beispiel: Mit 2 Kreuz gespielt = 12 × 3 = 36.'),
    ('Stichspiel',
        'Vorhand spielt aus. Es herrscht Bedienpflicht: Wer die ausgespielte Farbe (oder Trumpf) hat, muss sie zugeben. Wer nicht bedienen kann, darf frei zugeben, '
            'auch einen Trumpf. Wer den Stich gewinnt, spielt als Nächster aus.\n\n'
            'In der App kannst du nur Karten spielen, die erlaubt sind; alle anderen werden abgedunkelt und abgelehnt.'),
    ('Gewinn und Verlust',
        'Der Alleinspieler gewinnt mit mindestens 61 Augen. Gewonnen: er bekommt den Spielwert gutgeschrieben. Verloren: ihm wird der doppelte Spielwert abgezogen.\n\n'
            'Hat er überreizt (sein Spielwert ist kleiner als sein Reizgebot), ist das Spiel automatisch verloren.'),
    ('In dieser App (Hinweise)',
        'Nicht enthalten sind Ramsch, Kontra/Re und Bockrunden. Beim Punkte-Notieren kannst du alles manuell eintragen.\n\n'
            'Das deutsche Blatt entspricht den Farben: Schellen = Karo, Herz = Herz, Laub = Pik, Eichel = Kreuz; Unter = Bube, Ober = Dame, Daus = Ass.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spielregeln')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < _sections.length; i++)
            ExpansionTile(
              initiallyExpanded: i == 0,
              title: Text(_sections[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(_sections[i].$2, style: const TextStyle(height: 1.4))],
            ),
        ],
      ),
    );
  }
}
