import 'package:flutter/material.dart';
import '../logic/settings_store.dart';
import '../models/poker_models.dart';
import 'hand_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  AppSettings s = AppSettings.defaults();
  bool loaded = false;

  final _sbCtl = TextEditingController();
  final _bbCtl = TextEditingController();
  final _anteCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SettingsStore.load().then((v) {
      setState(() {
        s = v;
        loaded = true;
        _sbCtl.text = s.sb.toString();
        _bbCtl.text = s.bb.toString();
        _anteCtl.text = s.ante.toString();
      });
    });
  }

  @override
  void dispose() {
    _sbCtl.dispose();
    _bbCtl.dispose();
    _anteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sb = double.tryParse(_sbCtl.text) ?? s.sb;
    final bb = double.tryParse(_bbCtl.text) ?? s.bb;
    final ante = double.tryParse(_anteCtl.text) ?? s.ante;

    final ss = s.copyWith(sb: sb, bb: bb, ante: ante);
    setState(() => s = ss);
    await SettingsStore.save(ss);
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("AssistantSG — Impostazioni")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("Tavolo di gioco attuale"),
          Row(
            children: [
              const Expanded(child: Text("Modalità")),
              SegmentedButton<GameMode>(
                segments: const [
                  ButtonSegment(value: GameMode.cash, label: Text("Cash")),
                  ButtonSegment(
                      value: GameMode.tournament, label: Text("Torneo")),
                ],
                selected: {s.mode},
                onSelectionChanged: (v) async {
                  setState(() => s = s.copyWith(mode: v.first));
                  await _save();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("Giocatori al tavolo (max 9)")),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  setState(() => s = s.copyWith(
                      playersAtTable: (s.playersAtTable - 1).clamp(2, 9)));
                  await _save();
                },
              ),
              Text("${s.playersAtTable}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  setState(() => s = s.copyWith(
                      playersAtTable: (s.playersAtTable + 1).clamp(2, 9)));
                  await _save();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("Posizione iniziale (tu)")),
              DropdownButton<Pos9Max>(
                value: s.startPos,
                items: Pos9Max.values
                    .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => s = s.copyWith(startPos: v));
                  await _save();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("SB")),
              SizedBox(
                  width: 120,
                  child: TextField(
                      controller: _sbCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _save())),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text("BB")),
              SizedBox(
                  width: 120,
                  child: TextField(
                      controller: _bbCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _save())),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                  child: Text("Ante (tutti mettono prima della mano)")),
              SizedBox(
                  width: 120,
                  child: TextField(
                      controller: _anteCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _save())),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                  child:
                      Text("Simulazioni (più = più accurato, ma più lento)")),
              DropdownButton<int>(
                value: s.iterations,
                items: const [
                  DropdownMenuItem(value: 5000, child: Text("5000")),
                  DropdownMenuItem(value: 10000, child: Text("10000")),
                  DropdownMenuItem(value: 20000, child: Text("20000")),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => s = s.copyWith(iterations: v));
                  await _save();
                },
              ),
            ],
          ),
          const Divider(height: 28),
          _sectionTitle("Stile di gioco + parametrizzazione (si salva sempre)"),
          Row(
            children: [
              const Expanded(child: Text("Preset ranges")),
              DropdownButton<StylePreset>(
                value: s.preset,
                items: StylePreset.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  final open = AppSettings.presetOpenRaise(v);
                  setState(
                      () => s = s.copyWith(preset: v, openRaisePctByPos: open));
                  await _save();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("Open-raise % per posizione (modificabile)"),
          const SizedBox(height: 8),
          ...List.generate(Pos9Max.values.length, (i) {
            final p = Pos9Max.values[i];
            final pct = s.openRaisePctByPos[i];
            return Row(
              children: [
                SizedBox(width: 70, child: Text(p.label)),
                Expanded(
                  child: Slider(
                    value: pct.clamp(0, 80),
                    min: 0,
                    max: 80,
                    divisions: 80,
                    label: "${pct.toStringAsFixed(0)}%",
                    onChanged: (v) async {
                      final lst = List<double>.from(s.openRaisePctByPos);
                      lst[i] = v;
                      setState(() => s = s.copyWith(openRaisePctByPos: lst));
                      await _save();
                    },
                  ),
                ),
                SizedBox(width: 52, child: Text("${pct.toStringAsFixed(0)}%")),
              ],
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text("Call buffer Early (UTG…HJ)")),
              SizedBox(
                  width: 70,
                  child: Text("${s.callBufferEarly.toStringAsFixed(0)}%")),
            ],
          ),
          Slider(
            value: s.callBufferEarly.clamp(0, 30),
            min: 0,
            max: 30,
            divisions: 30,
            label: s.callBufferEarly.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(callBufferEarly: v));
              await _save();
            },
          ),
          Row(
            children: [
              const Expanded(child: Text("Call buffer Late (CO/BTN/SB)")),
              SizedBox(
                  width: 70,
                  child: Text("${s.callBufferLate.toStringAsFixed(0)}%")),
            ],
          ),
          Slider(
            value: s.callBufferLate.clamp(0, 40),
            min: 0,
            max: 40,
            divisions: 40,
            label: s.callBufferLate.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(callBufferLate: v));
              await _save();
            },
          ),
          const Divider(height: 28),
          _sectionTitle("Soglie equity (consigli più chiari)"),
          const Text(
              "Preflop: soglia = base - perOpp*(opp-1). Più avversari = soglie più basse."),
          const SizedBox(height: 6),
          Text("Raise base: ${s.preflopRaiseEqBase.toStringAsFixed(0)}%"),
          Slider(
            value: s.preflopRaiseEqBase.clamp(30, 70),
            min: 30,
            max: 70,
            divisions: 40,
            label: s.preflopRaiseEqBase.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(preflopRaiseEqBase: v));
              await _save();
            },
          ),
          Text("Raise perOpp: ${s.preflopRaiseEqPerOpp.toStringAsFixed(1)}"),
          Slider(
            value: s.preflopRaiseEqPerOpp.clamp(0, 8),
            min: 0,
            max: 8,
            divisions: 80,
            label: s.preflopRaiseEqPerOpp.toStringAsFixed(1),
            onChanged: (v) async {
              setState(() => s = s.copyWith(preflopRaiseEqPerOpp: v));
              await _save();
            },
          ),
          Text("Call base: ${s.preflopCallEqBase.toStringAsFixed(0)}%"),
          Slider(
            value: s.preflopCallEqBase.clamp(20, 60),
            min: 20,
            max: 60,
            divisions: 40,
            label: s.preflopCallEqBase.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(preflopCallEqBase: v));
              await _save();
            },
          ),
          Text("Call perOpp: ${s.preflopCallEqPerOpp.toStringAsFixed(1)}"),
          Slider(
            value: s.preflopCallEqPerOpp.clamp(0, 8),
            min: 0,
            max: 8,
            divisions: 80,
            label: s.preflopCallEqPerOpp.toStringAsFixed(1),
            onChanged: (v) async {
              setState(() => s = s.copyWith(preflopCallEqPerOpp: v));
              await _save();
            },
          ),
          const SizedBox(height: 10),
          const Text(
              "Postflop (se POT/BET non inseriti → modalità veloce solo equity)"),
          Text("Raise: ${s.postflopNoBetRaiseEq.toStringAsFixed(0)}%"),
          Slider(
            value: s.postflopNoBetRaiseEq.clamp(30, 90),
            min: 30,
            max: 90,
            divisions: 60,
            label: s.postflopNoBetRaiseEq.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(postflopNoBetRaiseEq: v));
              await _save();
            },
          ),
          Text("Call/Check: ${s.postflopNoBetCallEq.toStringAsFixed(0)}%"),
          Slider(
            value: s.postflopNoBetCallEq.clamp(10, 80),
            min: 10,
            max: 80,
            divisions: 70,
            label: s.postflopNoBetCallEq.toStringAsFixed(0),
            onChanged: (v) async {
              setState(() => s = s.copyWith(postflopNoBetCallEq: v));
              await _save();
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () async {
                await _save();
                if (!context.mounted) return;
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => HandScreen(settings: s)));
              },
              child: const Text("INIZIA (NUOVA MANO)"),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Nota: i pulsanti RAISE/CALL/FOLD NON bloccano nulla.\n"
            "Se fai CALL/CHECK puoi sempre andare avanti di street.",
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
