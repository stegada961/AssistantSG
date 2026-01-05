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
  bool loading = true;

  late AppSettings s;
  List<StyleProfile> profiles = [];
  String styleDropdownValue = "preset:balanced"; // default
  StyleProfile? selectedProfile;

  final sbCtl = TextEditingController();
  final bbCtl = TextEditingController();
  final anteCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    sbCtl.dispose();
    bbCtl.dispose();
    anteCtl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final ss = await SettingsStore.load();
    final pp = await SettingsStore.loadProfiles();
    setState(() {
      s = ss;
      profiles = pp;
      sbCtl.text = s.sb.toStringAsFixed(2);
      bbCtl.text = s.bb.toStringAsFixed(2);
      anteCtl.text = s.ante.toStringAsFixed(2);

      // dropdown iniziale coerente
      styleDropdownValue = "preset:${s.preset.name}";
      selectedProfile = null;
      loading = false;
    });
  }

  Future<void> _saveSettings() async {
    await SettingsStore.save(s);
  }

  List<DropdownMenuItem<String>> _styleItems() {
    final items = <DropdownMenuItem<String>>[];

    for (final p in StylePreset.values) {
      items.add(DropdownMenuItem(
        value: "preset:${p.name}",
        child: Text("Preset: ${p.name}"),
      ));
    }

    if (profiles.isNotEmpty) {
      items.add(const DropdownMenuItem(
        value: "sep",
        enabled: false,
        child: Text("— Profili salvati —"),
      ));
      for (final pr in profiles) {
        items.add(DropdownMenuItem(
          value: "profile:${pr.name}",
          child: Text(pr.name),
        ));
      }
    }

    return items;
  }

  Future<void> _applyStyleSelection(String v) async {
    if (v == "sep") return;

    setState(() {
      styleDropdownValue = v;
    });

    if (v.startsWith("preset:")) {
      final name = v.split(":")[1];
      final preset = StylePreset.values.firstWhere((x) => x.name == name);
      setState(() {
        selectedProfile = null;
        s = s.copyWith(preset: preset);
        // aggiorniamo anche openRaise coerente al preset (per non creare mismatch)
        s = s.copyWith(openRaisePctByPos: AppSettings._presetOpen(preset));
      });
      await _saveSettings();
      return;
    }

    if (v.startsWith("profile:")) {
      final name = v.substring("profile:".length);
      final pr = profiles.firstWhere((x) => x.name == name);
      setState(() {
        selectedProfile = pr;
        s = SettingsStore.applyStyleToSettings(s, pr);
      });
      await _saveSettings();
    }
  }

  Future<void> _saveProfileDialog() async {
    final ctl = TextEditingController(text: selectedProfile?.name ?? "SG");

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Salva stile"),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(hintText: "Nome profilo (es. SG)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text("Salva"),
          ),
        ],
      ),
    );

    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await SettingsStore.upsertProfile(trimmed, s);
    final pp = await SettingsStore.loadProfiles();

    setState(() {
      profiles = pp;
      styleDropdownValue = "profile:$trimmed";
      selectedProfile = profiles.firstWhere((p) => p.name.toLowerCase() == trimmed.toLowerCase());
    });
  }

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int decimals,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$title: ${value.toStringAsFixed(decimals)}"),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) async {
            onChanged(v);
            setState(() {});
            await _saveSettings();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("AssistantSG — Impostazioni")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Tavolo di gioco attuale", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            children: [
              const Text("Modalità"),
              const SizedBox(width: 16),
              SegmentedButton<GameMode>(
                segments: const [
                  ButtonSegment(value: GameMode.cash, label: Text("Cash")),
                  ButtonSegment(value: GameMode.torneo, label: Text("Torneo")),
                ],
                selected: {s.mode},
                onSelectionChanged: (set) async {
                  setState(() => s = s.copyWith(mode: set.first));
                  await _saveSettings();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: Text("Giocatori al tavolo (max 9): ${s.playersAtTable}")),
              IconButton(
                onPressed: () async {
                  setState(() => s = s.copyWith(playersAtTable: (s.playersAtTable - 1).clamp(2, 9)));
                  await _saveSettings();
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                onPressed: () async {
                  setState(() => s = s.copyWith(playersAtTable: (s.playersAtTable + 1).clamp(2, 9)));
                  await _saveSettings();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Expanded(child: Text("Posizione iniziale (tu)")),
              DropdownButton<Pos9Max>(
                value: s.startPos,
                items: Pos9Max.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => s = s.copyWith(startPos: v));
                  await _saveSettings();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: sbCtl,
            decoration: const InputDecoration(labelText: "SB"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (x) async {
              final v = double.tryParse(x) ?? s.sb;
              setState(() => s = s.copyWith(sb: v));
              await _saveSettings();
            },
          ),
          TextField(
            controller: bbCtl,
            decoration: const InputDecoration(labelText: "BB"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (x) async {
              final v = double.tryParse(x) ?? s.bb;
              setState(() => s = s.copyWith(bb: v));
              await _saveSettings();
            },
          ),
          TextField(
            controller: anteCtl,
            decoration: const InputDecoration(labelText: "Ante (tutti mettono prima della mano)"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (x) async {
              final v = double.tryParse(x) ?? s.ante;
              setState(() => s = s.copyWith(ante: v));
              await _saveSettings();
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Expanded(child: Text("Simulazioni (più = più accurato, ma più lento)")),
              DropdownButton<int>(
                value: s.iterations,
                items: const [5000, 10000, 20000, 40000]
                    .map((v) => DropdownMenuItem(value: v, child: Text("$v")))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => s = s.copyWith(iterations: v));
                  await _saveSettings();
                },
              ),
            ],
          ),

          const Divider(height: 32),

          const Text("Stile di gioco + parametrizzazione (si salva sempre)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            children: [
              const Expanded(child: Text("Stile di gioco")),
              DropdownButton<String>(
                value: styleDropdownValue,
                items: _styleItems(),
                onChanged: (v) async {
                  if (v == null) return;
                  await _applyStyleSelection(v);
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveProfileDialog,
                  icon: const Icon(Icons.save),
                  label: const Text("Salva stile…"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: selectedProfile == null
                      ? null
                      : () async {
                          await SettingsStore.upsertProfile(selectedProfile!.name, s);
                          final pp = await SettingsStore.loadProfiles();
                          setState(() => profiles = pp);
                        },
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text("Sovrascrivi"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text("Open-raise % per posizione (modificabile)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          for (int i = 0; i < 9; i++) ...[
            _slider(
              title: Pos9Max.values[i].label,
              value: s.openRaisePctByPos[i],
              min: 0,
              max: 60,
              decimals: 0,
              onChanged: (v) {
                final list = List<double>.from(s.openRaisePctByPos);
                list[i] = v;
                s = s.copyWith(openRaisePctByPos: list);
              },
            ),
          ],

          const Divider(height: 32),

          const Text("Soglie equity (consigli più chiari)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Preflop: soglia = base - perOpp*(opp-1). Più avversari = soglie più basse."),

          _slider(
            title: "Raise base (%)",
            value: s.preflopRaiseEqBase,
            min: 30,
            max: 65,
            decimals: 0,
            onChanged: (v) => s = s.copyWith(preflopRaiseEqBase: v),
          ),
          _slider(
            title: "Raise perOpp",
            value: s.preflopRaiseEqPerOpp,
            min: 0,
            max: 6,
            decimals: 1,
            onChanged: (v) => s = s.copyWith(preflopRaiseEqPerOpp: v),
          ),
          _slider(
            title: "Call base (%)",
            value: s.preflopCallEqBase,
            min: 20,
            max: 55,
            decimals: 0,
            onChanged: (v) => s = s.copyWith(preflopCallEqBase: v),
          ),
          _slider(
            title: "Call perOpp",
            value: s.preflopCallEqPerOpp,
            min: 0,
            max: 6,
            decimals: 1,
            onChanged: (v) => s = s.copyWith(preflopCallEqPerOpp: v),
          ),

          const SizedBox(height: 16),

          const Text("Postflop (se POT/BET non inseriti → modalità veloce solo equity)",
              style: TextStyle(fontWeight: FontWeight.bold)),

          _slider(
            title: "Raise (%)",
            value: s.postflopNoBetRaiseEq,
            min: 40,
            max: 85,
            decimals: 0,
            onChanged: (v) => s = s.copyWith(postflopNoBetRaiseEq: v),
          ),
          _slider(
            title: "Call/Check (%)",
            value: s.postflopNoBetCallEq,
            min: 15,
            max: 70,
            decimals: 0,
            onChanged: (v) => s = s.copyWith(postflopNoBetCallEq: v),
          ),

          const SizedBox(height: 18),

          FilledButton(
            onPressed: () async {
              await _saveSettings();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HandScreen(settings: s)),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text("INIZIA (NUOVA MANO)", style: TextStyle(fontSize: 18)),
            ),
          ),

          const SizedBox(height: 10),
          const Text("Nota: i pulsanti RAISE/CALL/FOLD NON bloccano nulla. Se fai CALL/CHECK puoi sempre andare avanti di street."),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
