import 'dart:math';
import 'hand_eval.dart';

class EquityRequest {
  final int hero1;
  final int hero2;
  final List<int> knownBoard; // 0..5
  final int opponents; // 1..8
  final int iterations; // 1000..200000
  EquityRequest({
    required this.hero1,
    required this.hero2,
    required this.knownBoard,
    required this.opponents,
    required this.iterations,
  });
}

class EquityResult {
  final double equity; // 0..100
  EquityResult(this.equity);
}

EquityResult computeEquity(EquityRequest req) {
  final rng = Random();
  final usedBase = List<bool>.filled(52, false);
  usedBase[req.hero1] = true;
  usedBase[req.hero2] = true;
  for (final c in req.knownBoard) {
    usedBase[c] = true;
  }

  int wins = 0;
  int ties = 0;

  for (int it = 0; it < req.iterations; it++) {
    final used = List<bool>.from(usedBase);

    // deal opponents
    final oppH1 = List<int>.filled(req.opponents, 0);
    final oppH2 = List<int>.filled(req.opponents, 0);
    for (int i = 0; i < req.opponents; i++) {
      oppH1[i] = dealRandom(rng, used);
      oppH2[i] = dealRandom(rng, used);
    }

    // complete board to 5
    final board = List<int>.filled(5, 0);
    int idx = 0;
    for (final c in req.knownBoard) {
      board[idx++] = c;
    }
    while (idx < 5) {
      board[idx++] = dealRandom(rng, used);
    }

    final heroScore = eval7Best(req.hero1, req.hero2, board);

    int best = heroScore;
    int bestCount = 1;
    bool heroBest = true;

    for (int i = 0; i < req.opponents; i++) {
      final os = eval7Best(oppH1[i], oppH2[i], board);
      if (os > best) {
        best = os;
        bestCount = 1;
        heroBest = false;
      } else if (os == best) {
        bestCount++;
        if (heroScore != best) heroBest = false;
      }
    }

    if (heroBest) {
      if (bestCount == 1) {
        wins++;
      } else {
        ties++;
      }
    }
  }

  final equity = (wins + ties / 2.0) / req.iterations * 100.0;
  return EquityResult(equity);
}
