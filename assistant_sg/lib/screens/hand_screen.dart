import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../logic/montecarlo.dart';
import '../logic/range_matrix.dart';
import '../models/poker_models.dart';
import 'widgets.dart';

class HandScreen extends StatefulWidget {
  final AppSettings settings;
  const HandScreen({super.key, required this.settings});

  @override
  State<HandScreen> createState() => _HandScreenState();
}

class _HandScreenState extends State<HandScreen> {
  late AppSettings s;
  Street street = Street.preflop;

  late Pos9Max pos;
  int playersInHand = 9;

  // Hero
  CardPick h1 = const CardPick();
  CardPick h2 = const CardPick();

  // Board
  CardPick f1 = const CardPick();
  CardPick f2 = const CardPick();
  CardPick f3 = const CardPick();
  CardPick t = const CardPick();
  CardPick r = const CardPick();

  // Postflop pot/bet optional
  final potCtl = TextEditingController(text: "");
  final betCtl = TextEditingController(text: "");

  double? equity;
  ActionRec rec = ActionRec.fold;
  String reason = "Seleziona le carte HERO (preflop)";

  bool matrixOpen = false;
  Timer? _debounce;

  static const ranks = [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2];
  static const rankLabel = {
    14: "A",
    13: "K",
    12: "Q",
    11: "J",
    10: "T",
    9: "9",
    8: "8",
    7: "7",
    6: "6",
    5: "5",
    4: "4",
    3: "3",
    2: "2",
  };

  static const suits = [0, 1, 2, 3];
  static const suitSymbol = {0: "♠", 1: "♥", 2: "♦", 3: "♣"};
  static const suitName = {0: "Picche", 1: "Cuori", 2: "Quadri", 3: "Fiori"};

  Color suitColor(int suit) =>
      (suit == 1 || suit == 2) ? Colors.red : Colors.black;

  @override
  void initState() {
    super.initState();
    s = widget.settings;
    pos = s.startPos;
    playersInHand = s.playersAtTable;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    potCtl.dispose();
    betCtl.dispose();
    super.dispose();
  }

  void newHand({bool rotatePos = true}) {
    setState(() {
      street = Street.preflop;
      if (rotatePos) pos = pos.next();
      playersInHand = s.playersAtTable;

      h1 = const CardPick();
      h2 = const CardPick();

      f1 = const CardPick();
      f2 = const CardPick();
      f3 = const CardPick();
      t = const CardPick();
      r = const CardPick();

      potCtl.text = "";
      betCtl.text = "";

      equity = null;
      rec = ActionRec.fold;
      reason = "Seleziona le carte HERO (preflop)";
    });
  }

  Color actionColor(ActionRec a) {
    switch (a) {
      case ActionRec.raise:
        return Colors.green;
      case ActionRec.call:
        return Colors.orange;
      case ActionRec.fold:
        return Colors.red;
    }
  }

  bool _hasHero() => h1.complete && h2.complete;

  bool _flopComplete() => f1.complete && f2.complete && f3.complete;
  bool _turnComplete() => t.complete;

  double? _tryNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double _potOrZero() => _tryNum(potCtl.text) ?? 0.0;
  double _betOrZero() => _tryNum(betCtl.text) ?? 0.0;

  double? _potOdds() {
    final bet = _tryNum(betCtl.text);
    if (bet == null || bet <= 0) return null;
    final pot = _tryNum(potCtl.text) ?? 0.0;
    return bet / (pot + bet);
  }

  // ✅ board parziale: include solo carte complete inserite
  List<int> _knownBoardIdsPartial() {
    final ids = <int>[];

    void addIfComplete(CardPick c) {
      final id = c.idOrNull();
      if (id != null) ids.add(id);
    }

    if (street.index >= Street.flop.index) {
      addIfComplete(f1);
      addIfComplete(f2);
      addIfComplete(f3);
    }
    if (street.index >= Street.turn.index) {
      addIfComplete(t);
    }
    if (street.index >= Street.river.index) {
      addIfComplete(r);
    }
    return ids;
  }

  bool _hasDuplicates(List<int> ids) {
    final set = <int>{};
    for (final x in ids) {
      if (set.contains(x)) return true;
      set.add(x);
    }
    return false;
  }

  ActionRec _baselineFromMatrix() {
    if (!_hasHero()) return ActionRec.fold;
    final label = holeTo169Label(h1.rank!, h1.suit!, h2.rank!, h2.suit!);
    final d = decisionForPos(s, pos);
    if (d.raise.contains(label)) return ActionRec.raise;
    if (d.call.contains(label)) return ActionRec.call;
    return ActionRec.fold;
  }

  ActionRec _combineAdvice(ActionRec base, double e) {
    if (street == Street.preflop) {
      final opp = (playersInHand - 1).clamp(1, 8);
      final raiseTh = clampd(
          s.preflopRaiseEqBase - s.preflopRaiseEqPerOpp * (opp - 1), 15, 75);
      final callTh = clampd(
          s.preflopCallEqBase - s.preflopCallEqPerOpp * (opp - 1), 10, 75);

      if (e >= raiseTh) return ActionRec.raise;
      if (e >= callTh)
        return base == ActionRec.raise ? ActionRec.raise : ActionRec.call;
      return ActionRec.fold;
    }

    final po = _potOdds();
    if (po == null) {
      if (e >= s.postflopNoBetRaiseEq) return ActionRec.raise;
      if (e >= s.postflopNoBetCallEq) return ActionRec.call;
      return ActionRec.fold;
    }

    final need = po * 100.0;
    if (e + 3 < need) return ActionRec.fold;
    if (e > need + 12) return ActionRec.raise;
    return ActionRec.call;
  }

  String _reasonText(ActionRec base, double e) {
    final opp = (playersInHand - 1).clamp(1, 8);

    if (street == Street.preflop) {
      final raiseTh = clampd(
          s.preflopRaiseEqBase - s.preflopRaiseEqPerOpp * (opp - 1), 15, 75);
      final callTh = clampd(
          s.preflopCallEqBase - s.preflopCallEqPerOpp * (opp - 1), 10, 75);

      return "Preflop • ${pos.label} • vs $opp\n"
          "Range base: ${base.name.toUpperCase()} • Equity: ${e.toStringAsFixed(1)}%\n"
          "Soglie: Raise≥${raiseTh.toStringAsFixed(1)}% • Call≥${callTh.toStringAsFixed(1)}%";
    }

    final po = _potOdds();
    if (po == null) {
      return "${street.name.toUpperCase()} • modalità veloce (senza POT/BET)\n"
          "Equity: ${e.toStringAsFixed(1)}% • Soglie: Raise≥${s.postflopNoBetRaiseEq.toStringAsFixed(0)}% • Call≥${s.postflopNoBetCallEq.toStringAsFixed(0)}%";
    }

    final need = (po * 100.0).toStringAsFixed(1);
    return "${street.name.toUpperCase()} • PotOdds attive\n"
        "Equity: ${e.toStringAsFixed(1)}% • PotOdds: $need%\n"
        "Pot ${_potOrZero()} / Bet ${_betOrZero()}";
  }

  void trigger() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () async {
      if (!_hasHero()) return;

      final hero1 = h1.idOrNull()!;
      final hero2 = h2.idOrNull()!;
      final board = _knownBoardIdsPartial();
      final used = <int>[hero1, hero2, ...board];

      if (_hasDuplicates(used)) {
        setState(() {
          equity = null;
          rec = ActionRec.fold;
          reason = "Errore: carte duplicate";
        });
        return;
      }

      final base = _baselineFromMatrix();
      setState(() => reason = "Calcolo equity…");

      final opp = (playersInHand - 1).clamp(1, 8);
      final res = await compute(
        computeEquity,
        EquityRequest(
          hero1: hero1,
          hero2: hero2,
          knownBoard: board, // ✅ 0..5 carte, parziale
          opponents: opp,
          iterations: s.iterations,
        ),
      );

      final e = double.parse(res.equity.toStringAsFixed(1));
      final combined = _combineAdvice(base, e);

      setState(() {
        equity = e;
        rec = combined;
        reason = _reasonText(base, e);
      });
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void nextStreet() {
    if (street == Street.preflop) {
      if (!_hasHero()) {
        _snack("Seleziona prima le 2 carte HERO.");
        return;
      }
      setState(() => street = Street.flop);
      trigger();
      return;
    }

    if (street == Street.flop) {
      if (!_flopComplete()) {
        _snack("Completa il FLOP (3 carte) prima di passare al TURN.");
        return;
      }
      setState(() => street = Street.turn);
      trigger();
      return;
    }

    if (street == Street.turn) {
      if (!_turnComplete()) {
        _snack("Inserisci il TURN prima di passare al RIVER.");
        return;
      }
      setState(() => street = Street.river);
      trigger();
      return;
    }

    // river: nuova mano
    newHand(rotatePos: true);
  }

  String _cardText(CardPick c) {
    if (!c.complete) return "—";
    final rr = rankLabel[c.rank] ?? "?";
    final ss = suitSymbol[c.suit] ?? "?";
    return "$rr$ss";
  }

  Widget _chipCard(CardPick c) {
    final txt = _cardText(c);
    Color col = Colors.black;
    if (c.complete) col = suitColor(c.suit!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        color: Colors.white,
      ),
      child: Text(txt,
          style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col)),
    );
  }

  Widget _summaryBoard() {
    // Mostra progressivamente: flop sopra al turn, flop+turn sopra al river
    final pieces = <Widget>[];

    if (street.index >= Street.turn.index) {
      pieces.add(
          const Text("FLOP:", style: TextStyle(fontWeight: FontWeight.bold)));
      pieces.add(const SizedBox(width: 8));
      pieces.add(_chipCard(f1));
      pieces.add(const SizedBox(width: 6));
      pieces.add(_chipCard(f2));
      pieces.add(const SizedBox(width: 6));
      pieces.add(_chipCard(f3));
    }

    if (street.index >= Street.river.index) {
      pieces.add(const SizedBox(width: 14));
      pieces.add(
          const Text("TURN:", style: TextStyle(fontWeight: FontWeight.bold)));
      pieces.add(const SizedBox(width: 8));
      pieces.add(_chipCard(t));
    }

    if (street == Street.river) {
      pieces.add(const SizedBox(width: 14));
      pieces.add(
          const Text("RIVER:", style: TextStyle(fontWeight: FontWeight.bold)));
      pieces.add(const SizedBox(width: 8));
      pieces.add(_chipCard(r));
    }

    if (pieces.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: pieces),
    );
  }

  Widget _heroSummary() {
    return Row(
      children: [
        const Text("Hai: ", style: TextStyle(fontSize: 16)),
        _chipCard(h1),
        const SizedBox(width: 8),
        _chipCard(h2),
      ],
    );
  }

  Widget _rangeMatrixWidget() {
    final d = decisionForPos(s, pos);

    String cellLabel(int hi, int lo, bool suited) {
      String f(int r) => rankLabel[r]!;
      if (hi == lo) return "${f(hi)}${f(lo)}";
      return "${f(hi)}${f(lo)}${suited ? "s" : "o"}";
    }

    Color cellColor(String lab) {
      if (d.raise.contains(lab)) return Colors.green.withValues(alpha: 0.55);
      if (d.call.contains(lab)) return Colors.orange.withValues(alpha: 0.55);
      return Colors.red.withValues(alpha: 0.25);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Range (13×13)",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: ranks.map((rowR) {
              return Row(
                children: ranks.map((colR) {
                  final hi = rowR;
                  final lo = colR;
                  final suited = (hi < lo);
                  final a = hi >= lo ? hi : lo;
                  final b = hi >= lo ? lo : hi;
                  final lab = (a == b)
                      ? cellLabel(a, b, false)
                      : cellLabel(a, b, suited);

                  return Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.all(1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cellColor(lab),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rankLabel[a]!,
                        style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Text("Verde=Raise • Giallo=Call • Rosso=Fold",
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = equity;
    final color = actionColor(rec);

    final header = Material(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${street.name.toUpperCase()} • ${pos.label}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _heroSummary(),
            const SizedBox(height: 10),
            if (street.index >= Street.turn.index) _summaryBoard(),
            if (street.index >= Street.turn.index) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    e == null
                        ? "Equity: —"
                        : "Equity: ${e.toStringAsFixed(1)}%",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                IconButton(
                  onPressed: () => newHand(rotatePos: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: "Nuova mano (+1 posizione)",
                ),
              ],
            ),
            Text(reason),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: rec == ActionRec.raise
                          ? Colors.green
                          : Colors.green.withValues(alpha: 0.25),
                    ),
                    icon: const Icon(Icons.trending_up),
                    label: const Text("RAISE"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: nextStreet,
                    style: FilledButton.styleFrom(
                      backgroundColor: rec == ActionRec.call
                          ? Colors.orange
                          : Colors.orange.withValues(alpha: 0.25),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                        street == Street.river ? "NUOVA MANO" : "CALL/CHECK →"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => newHand(rotatePos: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: rec == ActionRec.fold
                          ? Colors.red
                          : Colors.red.withValues(alpha: 0.25),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text("FOLD"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
                child: Text("Giocatori in mano (te incluso): $playersInHand")),
            IconButton(
              onPressed: () {
                setState(() => playersInHand = (playersInHand - 1).clamp(2, 9));
                trigger();
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              onPressed: () {
                setState(() => playersInHand = (playersInHand + 1).clamp(2, 9));
                trigger();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
            "SB ${s.sb} / BB ${s.bb} • Ante ${s.ante} • ${s.mode == GameMode.cash ? "Cash" : "Torneo"}"),
        const Divider(height: 26),

        // HERO picker SOLO preflop
        if (street == Street.preflop) ...[
          const Text("HERO (solo preflop)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Carta 1 (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: h1.rank,
            onPick: (v) {
              setState(() => h1 = CardPick(rank: v, suit: h1.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Carta 1 (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: h1.suit,
            onPick: (v) {
              setState(() => h1 = CardPick(rank: h1.rank, suit: v));
              trigger();
            },
          ),
          const SizedBox(height: 14),
          const Text("Carta 2 (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: h2.rank,
            onPick: (v) {
              setState(() => h2 = CardPick(rank: v, suit: h2.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Carta 2 (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: h2.suit,
            onPick: (v) {
              setState(() => h2 = CardPick(rank: h2.rank, suit: v));
              trigger();
            },
          ),
          const Divider(height: 26),
        ],

        // FLOP picker SOLO durante flop
        if (street == Street.flop) ...[
          const Text("FLOP (si aggiorna anche con 1 carta)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Flop 1 (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: f1.rank,
            onPick: (v) {
              setState(() => f1 = CardPick(rank: v, suit: f1.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Flop 1 (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: f1.suit,
            onPick: (v) {
              setState(() => f1 = CardPick(rank: f1.rank, suit: v));
              trigger();
            },
          ),
          const SizedBox(height: 12),
          const Text("Flop 2 (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: f2.rank,
            onPick: (v) {
              setState(() => f2 = CardPick(rank: v, suit: f2.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Flop 2 (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: f2.suit,
            onPick: (v) {
              setState(() => f2 = CardPick(rank: f2.rank, suit: v));
              trigger();
            },
          ),
          const SizedBox(height: 12),
          const Text("Flop 3 (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: f3.rank,
            onPick: (v) {
              setState(() => f3 = CardPick(rank: v, suit: f3.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Flop 3 (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: f3.suit,
            onPick: (v) {
              setState(() => f3 = CardPick(rank: f3.rank, suit: v));
              trigger();
            },
          ),
          const Divider(height: 26),
        ],

        // TURN picker SOLO durante turn (flop non più selezionabile, sta sopra nel riepilogo)
        if (street == Street.turn) ...[
          const Text("TURN",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Turn (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: t.rank,
            onPick: (v) {
              setState(() => t = CardPick(rank: v, suit: t.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("Turn (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: t.suit,
            onPick: (v) {
              setState(() => t = CardPick(rank: t.rank, suit: v));
              trigger();
            },
          ),
          const Divider(height: 26),
        ],

        // RIVER picker SOLO durante river (flop+turn non più selezionabili, stanno sopra nel riepilogo)
        if (street == Street.river) ...[
          const Text("RIVER",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("River (rank)"),
          ChipPicker<int>(
            values: ranks,
            label: (v) => rankLabel[v]!,
            selected: r.rank,
            onPick: (v) {
              setState(() => r = CardPick(rank: v, suit: r.suit));
              trigger();
            },
          ),
          const SizedBox(height: 6),
          const Text("River (seme)"),
          ChipPicker<int>(
            values: suits,
            label: (v) => "${suitSymbol[v]} ${suitName[v]}",
            selected: r.suit,
            onPick: (v) {
              setState(() => r = CardPick(rank: r.rank, suit: v));
              trigger();
            },
          ),
          const Divider(height: 26),
        ],

        // Pot/Bet (solo postflop) - opzionale
        if (street != Street.preflop) ...[
          const Text("POT/BET (opzionale)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("POT")),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: potCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: "es. 0.20"),
                  onChanged: (_) => trigger(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("BET da chiamare")),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: betCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: "es. 0.06"),
                  onChanged: (_) => trigger(),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
        ],

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Range per ${pos.label} (tap per aprire/chiudere)"),
          trailing: Icon(matrixOpen ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => matrixOpen = !matrixOpen),
        ),
        if (matrixOpen) _rangeMatrixWidget(),
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text("AssistantSG")),
      body: Column(
        children: [
          header, // ✅ sticky: equity sempre visibile
          Expanded(child: body),
        ],
      ),
    );
  }
}
