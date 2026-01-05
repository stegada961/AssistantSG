import 'dart:math';

int cardRank(int id) => (id ~/ 4) + 2; // 2..14
int cardSuit(int id) => id % 4; // 0..3

int _highestExcluding(List<int> cnt, int ex1, int ex2) {
  for (int r = 14; r >= 2; r--) {
    if (r != ex1 && r != ex2 && cnt[r] > 0) return r;
  }
  return 2;
}

// category: 8 SF, 7 4K, 6 FH, 5 FL, 4 ST, 3 3K, 2 2P, 1 1P, 0 HC
int eval5(int a, int b, int c, int d, int e) {
  final ids = [a, b, c, d, e];
  final r = List<int>.filled(5, 0);
  final s = List<int>.filled(5, 0);

  for (int i = 0; i < 5; i++) {
    r[i] = cardRank(ids[i]);
    s[i] = cardSuit(ids[i]);
  }

  r.sort((x, y) => y.compareTo(x));

  final isFlush =
      (s[0] == s[1] && s[1] == s[2] && s[2] == s[3] && s[3] == s[4]);

  bool isStraight = false;
  int highStraight = r[0];

  // wheel A-5
  if (r[0] == 14 && r[1] == 5 && r[2] == 4 && r[3] == 3 && r[4] == 2) {
    isStraight = true;
    highStraight = 5;
  } else if (r[0] == r[1] + 1 &&
      r[1] == r[2] + 1 &&
      r[2] == r[3] + 1 &&
      r[3] == r[4] + 1) {
    isStraight = true;
    highStraight = r[0];
  }

  final cnt = List<int>.filled(15, 0);
  for (final x in r) {
    cnt[x]++;
  }

  int four = 0, three = 0;
  final pairs = <int>[];
  for (int rr = 14; rr >= 2; rr--) {
    if (cnt[rr] == 4) four = rr;
    if (cnt[rr] == 3) three = rr;
    if (cnt[rr] == 2) pairs.add(rr);
  }

  int cat = 0;
  final k = List<int>.filled(5, 0);

  if (isStraight && isFlush) {
    cat = 8;
    k[0] = highStraight;
  } else if (four > 0) {
    cat = 7;
    k[0] = four;
    k[1] = _highestExcluding(cnt, four, -1);
  } else if (three > 0 && pairs.isNotEmpty) {
    cat = 6;
    k[0] = three;
    k[1] = pairs[0];
  } else if (isFlush) {
    cat = 5;
    k.setAll(0, r);
  } else if (isStraight) {
    cat = 4;
    k[0] = highStraight;
  } else if (three > 0) {
    cat = 3;
    k[0] = three;
    int idx = 1;
    for (int rr = 14; rr >= 2; rr--) {
      if (cnt[rr] == 1) k[idx++] = rr;
    }
  } else if (pairs.length == 2) {
    cat = 2;
    k[0] = pairs[0];
    k[1] = pairs[1];
    k[2] = _highestExcluding(cnt, pairs[0], pairs[1]);
  } else if (pairs.length == 1) {
    cat = 1;
    k[0] = pairs[0];
    int idx = 1;
    for (int rr = 14; rr >= 2; rr--) {
      if (cnt[rr] == 1) k[idx++] = rr;
    }
  } else {
    cat = 0;
    k.setAll(0, r);
  }

  // score big int-like
  int score = cat * 10000000000;
  int mul = 100000000;
  for (int i = 0; i < 5; i++) {
    score += k[i] * mul;
    mul ~/= 100;
  }
  return score;
}

int eval7Best(int h1, int h2, List<int> board5) {
  final cards = <int>[h1, h2, ...board5];
  int best = -1;

  for (int a = 0; a < 3; a++) {
    for (int b = a + 1; b < 4; b++) {
      for (int c = b + 1; c < 5; c++) {
        for (int d = c + 1; d < 6; d++) {
          for (int e = d + 1; e < 7; e++) {
            final sc = eval5(cards[a], cards[b], cards[c], cards[d], cards[e]);
            if (sc > best) best = sc;
          }
        }
      }
    }
  }
  return best;
}

int dealRandom(Random rng, List<bool> used) {
  int id;
  do {
    id = rng.nextInt(52);
  } while (used[id]);
  used[id] = true;
  return id;
}
