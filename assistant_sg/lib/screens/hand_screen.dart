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

  late Pos9Max pos; // +1 per nuova mano
  int playersInHand = 9;

  CardPick h1 = const CardPick();
  CardPick h2 = const CardPick();

  CardPick f1 = const CardPick();
  CardPick f2 = const CardPick();
  CardPick f3 = const CardPick();
  CardPick t = const CardPick();
  CardPick r = const CardPick();

  final potCtl = TextEditingController(text: "");
  final betCtl = TextEditingController(text: "");

  double? equity;
  ActionRec rec = ActionRec.fold;
  String reason = "Seleziona 2 carte Hero";

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

  Color suitColor(int s) => (s == 1 || s == 2) ? Colors.red : Colors.black;

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

  void newHand() {
    setState(() {
      street = Street.preflop;
      pos = pos.next();
      playersInHand = s.playersAtTable;

      h1 = const CardPick();
      h2 = const CardPick();
      f1 = const CardPick();
      f2 = const CardPick();
      f3 = const CardPick();
      t = const CardPick();
      r = const CardPick();

      equity = null;
      rec = ActionRec.fold;
      reason = "Seleziona 2 carte Hero";
      potCtl.text = "";
      betCtl.text = "";
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

  double? _tryNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double _potOrZero() => _tryNum(potCtl.text) ?? 0.0;
  double _betOrZero() => _tryNum(betCtl.text) ?? 0.0;

  double? _potOdds() {
    // Se BET non inserita (vuoto/0) => modalità veloce, non vincolante
    final bet = _tryNum(betCtl.text);
    if (bet == null || bet <= 0) return null;
    final pot = _tryNum(potCtl.text) ?? 0.0;
    return bet / (pot + bet);
  }

  List<int>? _knownBoardIds() {
    final ids = <int>[];
    if (street.index >= Street.flop.index) {
      final a = f1.idOrNull(), b = f2.idOrNull(), c = f3.idOrNull();
      if (a == null || b == null || c == null) return null;
      ids.addAll([a, b, c]);
    }
    if (street.index >= Street.turn.index) {
      final x = t.idOrNull();
      if (x == null) return null;
      ids.add(x);
    }
    if (street.index >= Street.river.index) {
      final x = r.idOrNull();
      if (x == null) return null;
      ids.add(x);
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

  ActionRec _baselineFromRange() {
    // baseline per posizione usando 169 range
    if (!_hasHero()) return ActionRec.fold;
    final label = holeTo169Label(h1.rank!, h1.suit!, h2.rank!, h2.suit!);
    final d = decisionForPos(s, pos);
    if (d.raise.contains(label)) return ActionRec.raise;
    if (d.call.contains(label)) return ActionRec.call;
    return ActionRec.fold;
  }

  ActionRec _combineAdvice(ActionRec base, double e) {
    // PRE-FLOP: soglie parametrizzate e scalate per #avversari
    if (street == Street.preflop) {
      final opp = (playersInHand - 1).clamp(1, 8);

      final raiseTh =
          (s.preflopRaiseEqBase - s.preflopRaiseEqPerOpp * (opp - 1))
              .clamp(30, 70);
      final callTh = (s.preflopCallEqBase - s.preflopCallEqPerOpp * (opp - 1))
          .clamp(15, 65);

      if (e >= raiseTh) return ActionRec.raise;
      if (e >= callTh) {
        // se base era già raise, resta raise
        return base == ActionRec.raise ? ActionRec.raise : ActionRec.call;
      }
      return ActionRec.fold;
    }

    // POST-FLOP:
    // - se POT/BET non inseriti -> modalità veloce (solo equity)
    // - se inserisci BET -> usa pot-odds
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

  String _explain(ActionRec base, double e) {
    final opp = (playersInHand - 1).clamp(1, 8);

    if (street == Street.preflop) {
      final raiseTh =
          (s.preflopRaiseEqBase - s.preflopRaiseEqPerOpp * (opp - 1))
              .clamp(30, 70);
      final callTh = (s.preflopCallEqBase - s.preflopCallEqPerOpp * (opp - 1))
          .clamp(15, 65);

      return "Posizione ${pos.label} (vs $opp) • Range base: ${base.name.toUpperCase()}\n"
          "Equity ${e.toStringAsFixed(1)}% • Soglie: RAISE≥${raiseTh.toStringAsFixed(0)}%  CALL≥${callTh.toStringAsFixed(0)}%\n"
          "Legenda: Verde=Raise, Giallo=Call/Check, Rosso=Fold";
    }

    final po = _potOdds();
    if (po == null) {
      return "Postflop • Modalità veloce (POT/BET non inseriti)\n"
          "Equity ${e.toStringAsFixed(1)}% • Soglie: RAISE≥${s.postflopNoBetRaiseEq.toStringAsFixed(0)}%  CALL≥${s.postflopNoBetCallEq.toStringAsFixed(0)}%";
    }

    final need = (po * 100).toStringAsFixed(1);
    return "Postflop • PotOdds = $need% (devi vincere almeno $need%)\n"
        "Pot ${_potOrZero()} / Bet ${_betOrZero()} • Equity ${e.toStringAsFixed(1)}%";
  }

  void trigger() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () async {
      if (!_hasHero()) return;

      final hero1 = h1.idOrNull()!;
      final hero2 = h2.idOrNull()!;
      final board = _knownBoardIds() ?? const <int>[];

      final used = <int>[hero1, hero2, ...board];
      if (_hasDuplicates(used)) {
        setState(() {
          equity = null;
          rec = ActionRec.fold;
          reason = "Errore: hai selezionato carte duplicate.";
        });
        return;
      }

      final base = _baselineFromRange();
      setState(() => reason = "Calcolo equity…");

      final opp = (playersInHand - 1).clamp(1, 8);
      final res = await compute(
        computeEquity,
        EquityRequest(
          hero1: hero1,
          hero2: hero2,
          knownBoard: board,
          opponents: opp,
          iterations: s.iterations,
        ),
      );

      final e = double.parse(res.equity.toStringAsFixed(1));
      final combined = _combineAdvice(base, e);

      setState(() {
        equity = e;
        rec = combined;
        reason = _explain(base, e);
      });
    });
  }

  void nextStreet() {
    setState(() {
      if (street == Street.preflop) {
        street = Street.flop;
      } else if (street == Street.flop) {
        street = Street.turn;
      } else if (street == Street.turn) {
        street = Street.river;
      }
    });
    trigger();
  }

  Widget _rangeSummary() {
    final d = decisionForPos(s, pos);
    final raisePct = d.raisePct.toStringAsFixed(0);
    final callPct = d.callPct.toStringAsFixed(0);
    final foldPct = d.foldPct.toStringAsFixed(0);

    return Text(
      "Range ${pos.label}: Raise ~$raisePct% • Call ~$callPct% • Fold ~$foldPct%",
      style: const TextStyle(fontSize: 12),
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
        const Text("Range 13×13 (tap per scegliere idea veloce)",
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

  Widget _cardPicker(
      String title, CardPick current, void Function(CardPick) setCard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        ChipPicker<int>(
          values: ranks,
          label: (v) => rankLabel[v]!,
          selected: current.rank,
          onPick: (v) {
            setCard(CardPick(rank: v, suit: current.suit));
            trigger();
          },
        ),
        const SizedBox(height: 6),
        ChipPicker<int>(
          values: suits,
          label: (v) => "${suitSymbol[v]} ${suitName[v]}",
          selected: current.suit,
          colorOf: (v) => suitColor(v),
          onPick: (v) {
            setCard(CardPick(rank: current.rank, suit: v));
            trigger();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = equity;
    final color = actionColor(rec);

    return Scaffold(
      appBar: AppBar(
        title: Text("${street.name.toUpperCase()} • ${pos.label}"),
        actions: [
          IconButton(
              onPressed: newHand,
              icon: const Icon(Icons.refresh),
              tooltip: "Nuova mano (+1 posizione)"),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                  child: Text("Players in hand (te incluso): $playersInHand")),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  setState(
                      () => playersInHand = (playersInHand - 1).clamp(2, 9));
                  trigger();
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  setState(
                      () => playersInHand = (playersInHand + 1).clamp(2, 9));
                  trigger();
                },
              ),
            ],
          ),
          Text(
              "SB ${s.sb} / BB ${s.bb} • Ante ${s.ante} • ${s.mode == GameMode.cash ? "Cash" : "Torneo"}"),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e == null ? "Equity: —" : "Equity: ${e.toStringAsFixed(1)}%",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 6),
                Text(reason),
                const SizedBox(height: 6),
                _rangeSummary(),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // AZIONI: NON bloccanti (tu decidi sempre)
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
                  onPressed: () async {
                    // Se fai call/check puoi SEMPRE andare avanti
                    final go = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title:
                            const Text("Vuoi passare alla street successiva?"),
                        content: const Text(
                            "Questo non cambia il consiglio: ti fa solo avanzare di street."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("NO")),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("SÌ")),
                        ],
                      ),
                    );
                    if (go == true) nextStreet();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: rec == ActionRec.call
                        ? Colors.orange
                        : Colors.orange.withValues(alpha: 0.25),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("CHECK/CALL"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    newHand();
                  },
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

          const SizedBox(height: 10),

          if (street != Street.preflop) ...[
            const Text(
                "POT e BET (facoltativi). Se li lasci vuoti: modalità veloce solo equity."),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text("POT")),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: potCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => trigger(),
                    decoration: const InputDecoration(hintText: "es. 10"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text("BET da chiamare")),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: betCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => trigger(),
                    decoration: const InputDecoration(hintText: "es. 5"),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 26),

          const Text("HERO",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _cardPicker("Carta 1", h1, (x) => setState(() => h1 = x)),
          const SizedBox(height: 12),
          _cardPicker("Carta 2", h2, (x) => setState(() => h2 = x)),

          const Divider(height: 26),

          if (street.index >= Street.flop.index) ...[
            const Text("FLOP",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _cardPicker("Flop 1", f1, (x) => setState(() => f1 = x)),
            const SizedBox(height: 10),
            _cardPicker("Flop 2", f2, (x) => setState(() => f2 = x)),
            const SizedBox(height: 10),
            _cardPicker("Flop 3", f3, (x) => setState(() => f3 = x)),
          ],

          if (street.index >= Street.turn.index) ...[
            const Divider(height: 26),
            const Text("TURN",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _cardPicker("Turn", t, (x) => setState(() => t = x)),
          ],

          if (street.index >= Street.river.index) ...[
            const Divider(height: 26),
            const Text("RIVER",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _cardPicker("River", r, (x) => setState(() => r = x)),
          ],

          const Divider(height: 26),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Range per ${pos.label} (apri/chiudi)"),
            trailing: Icon(matrixOpen ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => matrixOpen = !matrixOpen),
          ),
          if (matrixOpen) _rangeMatrixWidget(),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
