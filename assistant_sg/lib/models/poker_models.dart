import 'dart:math';

enum GameMode { cash, torneo }

enum Street { preflop, flop, turn, river }

enum ActionRec { raise, call, fold }

enum StylePreset { tight, balanced, aggressive }

// Posizioni 9-max (ma l’app può usare 6-max impostando playersAtTable)
enum Pos9Max { utg, utg1, mp, lj, hj, co, btn, sb, bb }

extension Pos9MaxX on Pos9Max {
  String get label {
    switch (this) {
      case Pos9Max.utg:
        return "UTG";
      case Pos9Max.utg1:
        return "UTG+1";
      case Pos9Max.mp:
        return "MP";
      case Pos9Max.lj:
        return "LJ";
      case Pos9Max.hj:
        return "HJ";
      case Pos9Max.co:
        return "CO";
      case Pos9Max.btn:
        return "BTN";
      case Pos9Max.sb:
        return "SB";
      case Pos9Max.bb:
        return "BB";
    }
  }

  Pos9Max next() {
    final idx = (index + 1) % Pos9Max.values.length;
    return Pos9Max.values[idx];
  }
}

/// Carta scelta (rank 2..14, suit 0..3)
class CardPick {
  final int? rank;
  final int? suit;

  const CardPick({this.rank, this.suit});

  bool get complete => rank != null && suit != null;

  int? idOrNull() {
    if (!complete) return null;
    // 52 cards: (rank-2)*4 + suit
    return (rank! - 2) * 4 + suit!;
  }
}

class AppSettings {
  final GameMode mode;
  final int playersAtTable;
  final Pos9Max startPos;

  final double sb;
  final double bb;
  final double ante;

  final int iterations;

  // Stile / ranges
  final StylePreset preset;

  /// Percentuali open-raise per posizione (sempre 9 valori, UTG..BB).
  final List<double> openRaisePctByPos;

  // Parametri range (call/check “più largo”)
  final double callBufferEarly; // posizioni early
  final double callBufferLate; // posizioni late

  // Soglie equity preflop
  final double preflopRaiseEqBase;
  final double preflopRaiseEqPerOpp;
  final double preflopCallEqBase;
  final double preflopCallEqPerOpp;

  // Postflop senza POT/BET (equity-only)
  final double postflopNoBetRaiseEq;
  final double postflopNoBetCallEq;

  const AppSettings({
    required this.mode,
    required this.playersAtTable,
    required this.startPos,
    required this.sb,
    required this.bb,
    required this.ante,
    required this.iterations,
    required this.preset,
    required this.openRaisePctByPos,
    required this.callBufferEarly,
    required this.callBufferLate,
    required this.preflopRaiseEqBase,
    required this.preflopRaiseEqPerOpp,
    required this.preflopCallEqBase,
    required this.preflopCallEqPerOpp,
    required this.postflopNoBetRaiseEq,
    required this.postflopNoBetCallEq,
  });

  factory AppSettings.defaults() {
    // default “balanced”
    final preset = StylePreset.balanced;
    return AppSettings(
      mode: GameMode.cash,
      playersAtTable: 6,
      startPos: Pos9Max.bb,
      sb: 0.01,
      bb: 0.02,
      ante: 0.0,
      iterations: 20000,
      preset: preset,
      openRaisePctByPos: presetOpenRaise(preset),
      callBufferEarly: 7,
      callBufferLate: 10,
      preflopRaiseEqBase: 46,
      preflopRaiseEqPerOpp: 2.5,
      preflopCallEqBase: 34,
      preflopCallEqPerOpp: 1.5,
      postflopNoBetRaiseEq: 62,
      postflopNoBetCallEq: 38,
    );
  }

  static List<double> presetOpenRaise(StylePreset p) {
    // 9-max: UTG..BB
    switch (p) {
      case StylePreset.tight:
        return [12, 13, 15, 17, 19, 22, 28, 18, 0];
      case StylePreset.balanced:
        return [15, 16, 18, 20, 22, 26, 34, 22, 0];
      case StylePreset.aggressive:
        return [18, 19, 21, 24, 26, 30, 40, 26, 0];
    }
  }

  AppSettings copyWith({
    GameMode? mode,
    int? playersAtTable,
    Pos9Max? startPos,
    double? sb,
    double? bb,
    double? ante,
    int? iterations,
    StylePreset? preset,
    List<double>? openRaisePctByPos,
    double? callBufferEarly,
    double? callBufferLate,
    double? preflopRaiseEqBase,
    double? preflopRaiseEqPerOpp,
    double? preflopCallEqBase,
    double? preflopCallEqPerOpp,
    double? postflopNoBetRaiseEq,
    double? postflopNoBetCallEq,
  }) {
    return AppSettings(
      mode: mode ?? this.mode,
      playersAtTable: playersAtTable ?? this.playersAtTable,
      startPos: startPos ?? this.startPos,
      sb: sb ?? this.sb,
      bb: bb ?? this.bb,
      ante: ante ?? this.ante,
      iterations: iterations ?? this.iterations,
      preset: preset ?? this.preset,
      openRaisePctByPos: openRaisePctByPos ?? this.openRaisePctByPos,
      callBufferEarly: callBufferEarly ?? this.callBufferEarly,
      callBufferLate: callBufferLate ?? this.callBufferLate,
      preflopRaiseEqBase: preflopRaiseEqBase ?? this.preflopRaiseEqBase,
      preflopRaiseEqPerOpp: preflopRaiseEqPerOpp ?? this.preflopRaiseEqPerOpp,
      preflopCallEqBase: preflopCallEqBase ?? this.preflopCallEqBase,
      preflopCallEqPerOpp: preflopCallEqPerOpp ?? this.preflopCallEqPerOpp,
      postflopNoBetRaiseEq: postflopNoBetRaiseEq ?? this.postflopNoBetRaiseEq,
      postflopNoBetCallEq: postflopNoBetCallEq ?? this.postflopNoBetCallEq,
    );
  }

  Map<String, dynamic> toJson() => {
        "mode": mode.index,
        "playersAtTable": playersAtTable,
        "startPos": startPos.index,
        "sb": sb,
        "bb": bb,
        "ante": ante,
        "iterations": iterations,
        "preset": preset.index,
        "openRaisePctByPos": openRaisePctByPos,
        "callBufferEarly": callBufferEarly,
        "callBufferLate": callBufferLate,
        "preflopRaiseEqBase": preflopRaiseEqBase,
        "preflopRaiseEqPerOpp": preflopRaiseEqPerOpp,
        "preflopCallEqBase": preflopCallEqBase,
        "preflopCallEqPerOpp": preflopCallEqPerOpp,
        "postflopNoBetRaiseEq": postflopNoBetRaiseEq,
        "postflopNoBetCallEq": postflopNoBetCallEq,
      };

  factory AppSettings.fromJson(Map<String, dynamic> m) {
    final preset = StylePreset.values[(m["preset"] as int?) ?? 1];
    final open = (m["openRaisePctByPos"] as List?)
            ?.map((x) => (x as num).toDouble())
            .toList() ??
        presetOpenRaise(preset);

    // Garantiamo 9 valori
    final open9 = List<double>.from(open);
    while (open9.length < 9) {
      open9.add(0);
    }
    if (open9.length > 9) open9.removeRange(9, open9.length);

    return AppSettings(
      mode: GameMode.values[(m["mode"] as int?) ?? 0],
      playersAtTable: (m["playersAtTable"] as int?) ?? 6,
      startPos: Pos9Max.values[(m["startPos"] as int?) ?? Pos9Max.bb.index],
      sb: ((m["sb"] as num?) ?? 0.01).toDouble(),
      bb: ((m["bb"] as num?) ?? 0.02).toDouble(),
      ante: ((m["ante"] as num?) ?? 0.0).toDouble(),
      iterations: (m["iterations"] as int?) ?? 20000,
      preset: preset,
      openRaisePctByPos: open9,
      callBufferEarly: ((m["callBufferEarly"] as num?) ?? 7).toDouble(),
      callBufferLate: ((m["callBufferLate"] as num?) ?? 10).toDouble(),
      preflopRaiseEqBase: ((m["preflopRaiseEqBase"] as num?) ?? 46).toDouble(),
      preflopRaiseEqPerOpp:
          ((m["preflopRaiseEqPerOpp"] as num?) ?? 2.5).toDouble(),
      preflopCallEqBase: ((m["preflopCallEqBase"] as num?) ?? 34).toDouble(),
      preflopCallEqPerOpp:
          ((m["preflopCallEqPerOpp"] as num?) ?? 1.5).toDouble(),
      postflopNoBetRaiseEq:
          ((m["postflopNoBetRaiseEq"] as num?) ?? 62).toDouble(),
      postflopNoBetCallEq:
          ((m["postflopNoBetCallEq"] as num?) ?? 38).toDouble(),
    );
  }
}

class StyleProfile {
  final String name;

  final StylePreset preset;
  final List<double> openRaisePctByPos;

  final double callBufferEarly;
  final double callBufferLate;

  final double preflopRaiseEqBase;
  final double preflopRaiseEqPerOpp;
  final double preflopCallEqBase;
  final double preflopCallEqPerOpp;

  final double postflopNoBetRaiseEq;
  final double postflopNoBetCallEq;

  const StyleProfile({
    required this.name,
    required this.preset,
    required this.openRaisePctByPos,
    required this.callBufferEarly,
    required this.callBufferLate,
    required this.preflopRaiseEqBase,
    required this.preflopRaiseEqPerOpp,
    required this.preflopCallEqBase,
    required this.preflopCallEqPerOpp,
    required this.postflopNoBetRaiseEq,
    required this.postflopNoBetCallEq,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "preset": preset.index,
        "openRaisePctByPos": openRaisePctByPos,
        "callBufferEarly": callBufferEarly,
        "callBufferLate": callBufferLate,
        "preflopRaiseEqBase": preflopRaiseEqBase,
        "preflopRaiseEqPerOpp": preflopRaiseEqPerOpp,
        "preflopCallEqBase": preflopCallEqBase,
        "preflopCallEqPerOpp": preflopCallEqPerOpp,
        "postflopNoBetRaiseEq": postflopNoBetRaiseEq,
        "postflopNoBetCallEq": postflopNoBetCallEq,
      };

  static StyleProfile fromJson(Map<String, dynamic> m) {
    final open = ((m["openRaisePctByPos"] as List?) ?? const [])
        .map((x) => (x as num).toDouble())
        .toList();
    final open9 = List<double>.from(open);
    while (open9.length < 9) {
      open9.add(0);
    }
    if (open9.length > 9) open9.removeRange(9, open9.length);

    return StyleProfile(
      name: (m["name"] as String?) ?? "Unnamed",
      preset: StylePreset.values[(m["preset"] as int?) ?? 1],
      openRaisePctByPos: open9,
      callBufferEarly: ((m["callBufferEarly"] as num?) ?? 7).toDouble(),
      callBufferLate: ((m["callBufferLate"] as num?) ?? 10).toDouble(),
      preflopRaiseEqBase: ((m["preflopRaiseEqBase"] as num?) ?? 46).toDouble(),
      preflopRaiseEqPerOpp:
          ((m["preflopRaiseEqPerOpp"] as num?) ?? 2.5).toDouble(),
      preflopCallEqBase: ((m["preflopCallEqBase"] as num?) ?? 34).toDouble(),
      preflopCallEqPerOpp:
          ((m["preflopCallEqPerOpp"] as num?) ?? 1.5).toDouble(),
      postflopNoBetRaiseEq:
          ((m["postflopNoBetRaiseEq"] as num?) ?? 62).toDouble(),
      postflopNoBetCallEq:
          ((m["postflopNoBetCallEq"] as num?) ?? 38).toDouble(),
    );
  }
}

// Utility piccola (comoda in altri file)
double clampd(double v, double lo, double hi) => max(lo, min(hi, v));
