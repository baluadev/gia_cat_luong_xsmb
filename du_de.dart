import 'dart:io';

import 'du_lo.dart';

/// =======================
/// LOAD CSV (NO PACKAGE)
/// =======================
Future<List<DataModel>> loadDataModels(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0); // remove header

  return lines.map((line) {
    final parts = line.split(',');
    return DataModel(
      date: parts[0],
      de: int.parse(parts[1]),
      others: parts.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

Future<void> main() async {
  // =======================
  // LOAD + SORT
  // =======================
  final data = await loadDataModels('data.csv');
  final num30LastestDays = data.take(500).map((e) => e.de).toList();
  print('num30LastestDays: $num30LastestDays');
  final model = LotteryProbabilityModel(num30LastestDays, windowSize: 60);
  final predictions = model.predict(topK: 20);

  int index = 0;
  for (final p in predictions) {
    print('${index++} $p');
  }

  final backtester = Backtester(
    history: data.take(500).map((e) => e.de).toList(),
    window: 60,
    topK: 10,
  );

  final result = backtester.run();

  print('Total days: ${result.totalDays}');
  print('Hit days  : ${result.hitDays}');
  print('Hit rate  : ${(result.hitRate * 100).toStringAsFixed(2)}%');
  print('Avg hits/day: ${result.avgHitPerDay.toStringAsFixed(3)}');
}

class ProbabilityResult {
  final int number;
  final double score;

  ProbabilityResult(this.number, this.score);

  @override
  String toString() =>
      'Number: ${number.toString().padLeft(2, '0')} | Score: ${score.toStringAsFixed(4)}';
}

class LotteryProbabilityModel {
  final List<int> history;
  final int windowSize;

  LotteryProbabilityModel(this.history, {this.windowSize = 60});

  List<ProbabilityResult> predict({int topK = 10}) {
    final recent = history.take(windowSize).toList();
    final freq = <int, int>{};
    final gaps = <int, List<int>>{};
    final lastSeen = <int, int>{};

    // init
    for (var i = 0; i < 100; i++) {
      freq[i] = 0;
      gaps[i] = [];
      lastSeen[i] = -1;
    }

    // frequency
    for (var i = 0; i < recent.length; i++) {
      final num = recent[i];
      freq[num] = freq[num]! + 1;

      if (lastSeen[num]! >= 0) {
        gaps[num]!.add(i - lastSeen[num]!);
      }
      lastSeen[num] = i;
    }

    // calculate scores
    final results = <ProbabilityResult>[];

    for (var i = 0; i < 100; i++) {
      final f = freq[i]! / windowSize;

      // overdue
      final currentGap =
          lastSeen[i]! == -1 ? windowSize : windowSize - lastSeen[i]!;
      final meanGap = gaps[i]!.isEmpty
          ? windowSize.toDouble()
          : gaps[i]!.reduce((a, b) => a + b) / gaps[i]!.length;

      final overdue = currentGap / meanGap;

      // hot penalty (nếu vừa xuất hiện trong 3 ngày)
      final hotPenalty = currentGap <= 3 ? 1.0 : 0.0;

      final score = 0.5 * f + 0.3 * overdue - 0.2 * hotPenalty;

      results.add(ProbabilityResult(i, score));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }
}

class LotteryModel {
  final int window;

  LotteryModel(this.window);

  List<int> predict(List<int> history, {int topK = 10}) {
    final freq = List<int>.filled(100, 0);
    final lastSeen = List<int>.filled(100, -1);

    for (var i = 0; i < history.length; i++) {
      final n = history[i];
      freq[n]++;
      lastSeen[n] = i;
    }

    final results = <ProbabilityResult>[];

    for (var i = 0; i < 100; i++) {
      final f = freq[i] / window;
      final gap = lastSeen[i] == -1 ? window : window - lastSeen[i];
      final score = 0.6 * f + 0.4 * (gap / window);
      results.add(ProbabilityResult(i, score));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).map((e) => e.number).toList();
  }
}

class BacktestResult {
  int totalDays = 0;
  int hitDays = 0;
  int totalBets = 0;
  int totalHits = 0;

  double get hitRate => totalDays == 0 ? 0 : hitDays / totalDays;

  double get avgHitPerDay => totalDays == 0 ? 0 : totalHits / totalDays;
}

class Backtester {
  final List<int> history;
  final int window;
  final int topK;

  Backtester({
    required this.history,
    this.window = 60,
    this.topK = 10,
  });

  BacktestResult run() {
    final model = LotteryModel(window);
    final result = BacktestResult();

    for (var i = window; i < history.length - 1; i++) {
      final train = history.sublist(i - window, i);
      final actual = history[i];

      final predictions = model.predict(train, topK: topK);

      result.totalDays++;
      result.totalBets += topK;

      if (predictions.contains(actual)) {
        result.hitDays++;
        result.totalHits++;
      }
    }

    return result;
  }
}
