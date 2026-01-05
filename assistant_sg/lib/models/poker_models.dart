enum GameMode { cash, tournament }

enum Street { preflop, flop, turn, river }

enum ActionRec { raise, call, fold }

enum StylePreset { tight, balanced, aggressive }

enum Pos9Max { utg, utg1, mp, lj, hj, co, btn, sb, bb }

extension Pos9MaxX on Pos9Max {
  String get label =>
      const ["UTG", "UTG+1", "MP", "LJ", "HJ", "CO", "BTN", "SB", "BB"][index];
  Pos9Max next() => Pos9Max.values[(index + 1) % Pos9Max.values.length];
}

class CardPick {
  final int? rank; // 2..14
  final int? suit; // 0..3
  const CardPick({this.rank, this.suit});
  bool get complete => rank != null && suit != null;

  int? idOrNull() {
    if (!complete) return null;
    return (rank! - 2) * 4 + suit!;
  }
}

class AppSettings {
  // Tavolo attuale
  final GameMode mode;
  final int playersAtTable; // 2..9
  final Pos9Max startPos;
  final int iterations;
  final double sb;
  final double bb;
  final double ante;

  // Stile + ranges
  final StylePreset preset;
  final List<double> openRaisePctByPos; // 9 valori: 0..80 circa
  final double callBufferEarly; // % aggiuntiva per call in pos early
  final double callBufferLate; // % aggiuntiva per call in pos late

  // Soglie equity (parametriche)
  // Preflop: soglie = base - perOpp*(opp-1), con clamp
  final double preflopRaiseEqBase;
  final double preflopRaiseEqPerOpp;
  final double preflopCallEqBase;
  final double preflopCallEqPerOpp;

  // Postflop se POT/BET non inseriti (modalità veloce)
  final double postflopNoBetRaiseEq;
  final double postflopNoBetCallEq;

  const AppSettings({
    required this.mode,
    required this.playersAtTable,
    required this.startPos,
    required this.iterations,
    required this.sb,
    required this.bb,
    required this.ante,
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

  AppSettings copyWith({
    GameMode? mode,
    int? playersAtTable,
    Pos9Max? startPos,
    int? iterations,
    double? sb,
    double? bb,
    double? ante,
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
      iterations: iterations ?? this.iterations,
      sb: sb ?? this.sb,
      bb: bb ?? this.bb,
      ante: ante ?? this.ante,
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

  static List<double> presetOpenRaise(StylePreset p) {
    // 9-max default: abbastanza "gioco un po' di mani"
    // [UTG,UTG+1,MP,LJ,HJ,CO,BTN,SB,BB]
    switch (p) {
      case StylePreset.tight:
        return [12, 13, 15, 17, 19, 24, 35, 18, 0];
      case StylePreset.balanced:
        return [14, 15, 17, 19, 22, 28, 42, 22, 0];
      case StylePreset.aggressive:
        return [18, 19, 21, 24, 28, 34, 50, 28, 0];
    }
  }

  static AppSettings defaults() => AppSettings(
        mode: GameMode.cash,
        playersAtTable: 9,
        startPos: Pos9Max.bb,
        iterations: 10000,
        sb: 0.5,
        bb: 1.0,
        ante: 0.0,
        preset: StylePreset.balanced,
        openRaisePctByPos: presetOpenRaise(StylePreset.balanced),
        callBufferEarly: 7.0,
        callBufferLate: 10.0,
        preflopRaiseEqBase: 52.0,
        preflopRaiseEqPerOpp: 3.0,
        preflopCallEqBase: 40.0,
        preflopCallEqPerOpp: 2.0,
        postflopNoBetRaiseEq: 62.0,
        postflopNoBetCallEq: 38.0,
      );
}
