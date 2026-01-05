import 'dart:math';
import '../models/poker_models.dart';

class Hand169 {
  final int r1; // high 14..2
  final int r2; // low 14..2
  final bool suited;
  Hand169(this.r1, this.r2, this.suited);

  String label() {
    String f(int r) => r == 14
        ? "A"
        : r == 13
            ? "K"
            : r == 12
                ? "Q"
                : r == 11
                    ? "J"
                    : r == 10
                        ? "T"
                        : "$r";
    if (r1 == r2) return "${f(r1)}${f(r2)}";
    return "${f(r1)}${f(r2)}${suited ? "s" : "o"}";
  }
}

double strength(Hand169 h) {
  final hi = h.r1;
  final lo = h.r2;

  if (hi == lo) return 200 + hi * 6; // coppie fortissime

  double s = hi * 4 + lo * 2;
  if (h.suited) s += 6;

  final gap = (hi - lo).abs();
  if (gap == 1) s += 3;
  if (gap == 2) s += 1.5;

  if (hi == 14) s += 4; // Ax bonus
  if (hi >= 11 && lo >= 10) s += 2; // broadway-ish
  return s;
}

List<Hand169> all169() {
  final out = <Hand169>[];
  for (int i = 14; i >= 2; i--) {
    for (int j = 14; j >= 2; j--) {
      if (i < j) continue;
      if (i == j) {
        out.add(Hand169(i, j, false));
      } else {
        out.add(Hand169(i, j, true));
        out.add(Hand169(i, j, false));
      }
    }
  }
  return out;
}

Set<String> topPercentHands(double pct) {
  final hands = all169();
  hands.sort((a, b) => strength(b).compareTo(strength(a)));
  final n = max(1, (hands.length * (pct / 100.0)).round());
  return hands.take(n).map((h) => h.label()).toSet();
}

class MatrixDecision {
  final Set<String> raise;
  final Set<String> call;
  MatrixDecision(this.raise, this.call);

  double get raisePct => raise.length / 169.0 * 100.0;
  double get callPct => call.length / 169.0 * 100.0;
  double get foldPct => 100.0 - raisePct - callPct;
}

MatrixDecision decisionForPos(AppSettings s, Pos9Max pos) {
  final open = s.openRaisePctByPos[pos.index].clamp(0.0, 100.0);

  final isLate = (pos == Pos9Max.co || pos == Pos9Max.btn || pos == Pos9Max.sb);
  final callBuffer = isLate ? s.callBufferLate : s.callBufferEarly;

  final raise = topPercentHands(open);
  final call =
      topPercentHands((open + callBuffer).clamp(0.0, 100.0)).difference(raise);
  return MatrixDecision(raise, call);
}

String holeTo169Label(int rA, int sA, int rB, int sB) {
  final hi = max(rA, rB);
  final lo = min(rA, rB);
  String f(int r) => r == 14
      ? "A"
      : r == 13
          ? "K"
          : r == 12
              ? "Q"
              : r == 11
                  ? "J"
                  : r == 10
                      ? "T"
                      : "$r";

  if (hi == lo) return "${f(hi)}${f(lo)}";
  final suited = (sA == sB);
  return "${f(hi)}${f(lo)}${suited ? "s" : "o"}";
}
