import 'dart:io';

class DataModel {
  final String date;
  final int de;
  final List<int> others;

  DataModel({
    required this.date,
    required this.de,
    required this.others,
  });
}

/// Thống kê cho một số cụ thể (0-99) sau khi có DE
class NumberStat {
  final int number;
  int appearanceCount = 0;
  int totalDays = 0;
  int hitDays = 0;
  final List<bool> history = [];
  int maxWinStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int currentLoseStreak = 0;

  NumberStat(this.number);

  double get winrate => totalDays == 0 ? 0 : (hitDays / totalDays * 100);
  double get frequency => totalDays == 0 ? 0 : (appearanceCount / totalDays);
  
  void addResult(bool appeared, int count) {
    totalDays++;
    if (appeared) {
      hitDays++;
      appearanceCount += count;
      currentWinStreak++;
      currentLoseStreak = 0;
      if (currentWinStreak > maxWinStreak) {
        maxWinStreak = currentWinStreak;
      }
      history.add(true);
    } else {
      currentLoseStreak++;
      currentWinStreak = 0;
      if (currentLoseStreak > maxLoseStreak) {
        maxLoseStreak = currentLoseStreak;
      }
      history.add(false);
    }
  }
}

/// Thống kê cho một cặp số
class PairStat {
  final int num1;
  final int num2;
  int hitDays = 0;
  int totalDays = 0;
  final List<bool> history = [];
  int maxWinStreak = 0;
  int maxLoseStreak = 0;

  PairStat(this.num1, this.num2);

  double get winrate => totalDays == 0 ? 0 : (hitDays / totalDays * 100);
  
  void addResult(bool hit) {
    totalDays++;
    if (hit) {
      hitDays++;
      history.add(true);
      final currentWin = _getCurrentStreak(true);
      if (currentWin > maxWinStreak) maxWinStreak = currentWin;
    } else {
      history.add(false);
      final currentLose = _getCurrentStreak(false);
      if (currentLose > maxLoseStreak) maxLoseStreak = currentLose;
    }
  }
  
  int _getCurrentStreak(bool isWin) {
    if (history.isEmpty) return 0;
    int streak = 0;
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i] == isWin) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

/// Kết quả backtest
class BacktestResult {
  final List<int> selectedNumbers;
  final String method;
  final int totalDays;
  final int hits;
  final int misses;
  final double winrate;
  final int profit;
  final double roi;
  final int maxWinStreak;
  final int maxLoseStreak;

  BacktestResult({
    required this.selectedNumbers,
    required this.method,
    required this.totalDays,
    required this.hits,
    required this.misses,
    required this.winrate,
    required this.profit,
    required this.roi,
    required this.maxWinStreak,
    required this.maxLoseStreak,
  });
}

Future<List<DataModel>> loadDataModels(String path) async {
  final lines = await File(path).readAsLines();
  lines.removeAt(0);

  return lines.map((line) {
    final parts = line.split(',');
    return DataModel(
      date: parts[0],
      de: int.parse(parts[1]),
      others: parts.sublist(2).map(int.parse).toList(),
    );
  }).toList();
}

/// 1️⃣ THỐNG KÊ TẦN SUẤT VÀ WINRATE CHO TỪNG SỐ (0-99)
Map<int, Map<int, NumberStat>> buildNumberStats(List<DataModel> sortedData) {
  final stats = <int, Map<int, NumberStat>>{};

  for (int i = 0; i < sortedData.length - 1; i++) {
    final today = sortedData[i];
    final tomorrow = sortedData[i + 1];
    final de = today.de;
    final tomorrowOthers = tomorrow.others;

    stats.putIfAbsent(de, () => {});
    final deStats = stats[de]!;

    final countMap = <int, int>{};
    for (final num in tomorrowOthers) {
      countMap[num] = (countMap[num] ?? 0) + 1;
    }

    for (int num = 0; num < 100; num++) {
      deStats.putIfAbsent(num, () => NumberStat(num));
      final stat = deStats[num]!;
      final appeared = countMap.containsKey(num);
      final count = countMap[num] ?? 0;
      stat.addResult(appeared, count);
    }
  }

  return stats;
}

/// 2️⃣ PAIR COMBINATION
Map<int, Map<String, PairStat>> buildPairStats(
  List<DataModel> sortedData,
  Map<int, Map<int, NumberStat>> numberStats,
) {
  final pairStats = <int, Map<String, PairStat>>{};

  for (int i = 0; i < sortedData.length - 1; i++) {
    final today = sortedData[i];
    final tomorrow = sortedData[i + 1];
    final de = today.de;
    final tomorrowOthersSet = tomorrow.others.toSet();

    pairStats.putIfAbsent(de, () => {});

    final deNumberStats = numberStats[de] ?? {};
    final topNumbers = deNumberStats.values.toList()
      ..sort((a, b) => b.winrate.compareTo(a.winrate));
    final top10 = topNumbers.take(10).map((s) => s.number).toList();

    final dePairStats = pairStats[de]!;
    for (int i = 0; i < top10.length; i++) {
      for (int j = i + 1; j < top10.length; j++) {
        final num1 = top10[i];
        final num2 = top10[j];
        final key = '${num1}_$num2';
        
        dePairStats.putIfAbsent(key, () => PairStat(num1, num2));
        final pairStat = dePairStats[key]!;
        
        final hit = tomorrowOthersSet.contains(num1) || tomorrowOthersSet.contains(num2);
        pairStat.addResult(hit);
      }
    }
  }

  return pairStats;
}

/// 3️⃣ MAX LOSE STREAK FILTERING
List<int> filterByMaxLoseStreak(
  Map<int, NumberStat> deStats,
  int maxAllowedLoseStreak,
) {
  return deStats.values
      .where((stat) => stat.maxLoseStreak <= maxAllowedLoseStreak)
      .map((stat) => stat.number)
      .toList();
}

/// 4️⃣ CONDITIONAL PROBABILITY SAU L/LL
Map<int, double> calculateConditionalProbability(
  Map<int, NumberStat> deStats,
) {
  final condProbs = <int, double>{};

  for (final stat in deStats.values) {
    if (stat.history.length < 2) {
      condProbs[stat.number] = stat.winrate;
      continue;
    }

    int afterL = 0;
    int afterLCount = 0;
    int afterLL = 0;
    int afterLLCount = 0;

    for (int i = 1; i < stat.history.length; i++) {
      if (!stat.history[i - 1]) {
        afterLCount++;
        if (stat.history[i]) {
          afterL++;
        }

        if (i >= 2 && !stat.history[i - 2]) {
          afterLLCount++;
          if (stat.history[i]) {
            afterLL++;
          }
        }
      }
    }

    final probAfterL = afterLCount > 0 ? (afterL / afterLCount * 100) : stat.winrate;
    final probAfterLL = afterLLCount > 0 ? (afterLL / afterLLCount * 100) : probAfterL;

    condProbs[stat.number] = afterLLCount >= 5 ? probAfterLL : probAfterL;
  }

  return condProbs;
}

/// 5️⃣ VOTING
List<int> votingMethod(
  Map<int, NumberStat> deStats,
  Map<String, PairStat> pairStats,
  int topN,
) {
  final byWinrate = deStats.values.toList()
    ..sort((a, b) => b.winrate.compareTo(a.winrate));
  final topByWinrate = byWinrate.take(topN).map((s) => s.number).toSet();

  final byFrequency = deStats.values.toList()
    ..sort((a, b) => b.frequency.compareTo(a.frequency));
  final topByFrequency = byFrequency.take(topN).map((s) => s.number).toSet();

  final pairStatsList = pairStats.values.toList()
    ..sort((a, b) => b.winrate.compareTo(a.winrate));
  final topPairs = <int>{};
  for (final pair in pairStatsList.take(topN)) {
    topPairs.add(pair.num1);
    topPairs.add(pair.num2);
  }

  final condProbs = calculateConditionalProbability(deStats);
  final byCondProb = condProbs.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topByCondProb = byCondProb.take(topN).map((e) => e.key).toSet();

  final votes = <int, int>{};
  for (final num in topByWinrate) votes[num] = (votes[num] ?? 0) + 1;
  for (final num in topByFrequency) votes[num] = (votes[num] ?? 0) + 1;
  for (final num in topPairs) votes[num] = (votes[num] ?? 0) + 1;
  for (final num in topByCondProb) votes[num] = (votes[num] ?? 0) + 1;

  final selected = votes.entries
      .where((e) => e.value >= 3)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) => votes[b]!.compareTo(votes[a]!));

  if (selected.isEmpty) {
    final allVoted = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return allVoted.take(topN).map((e) => e.key).toList();
  }

  return selected;
}

/// 6️⃣ CUT-LOSS
bool shouldStopDueToCutLoss(
  Map<int, NumberStat> deStats,
  List<int> selectedNumbers,
  int cutLossThreshold,
) {
  for (final num in selectedNumbers) {
    final stat = deStats[num];
    if (stat != null && stat.currentLoseStreak >= cutLossThreshold) {
      return true;
    }
  }
  return false;
}

/// BACKTEST MỘT PHƯƠNG PHÁP
BacktestResult backtestMethod(
  String methodName,
  List<DataModel> sortedData,
  Map<int, Map<int, NumberStat>> allStats,
  List<int> Function(int de, Map<int, NumberStat>, Map<String, PairStat>) selector,
  Map<int, Map<String, PairStat>>? pairStats,
  {int? cutLossThreshold}
) {
  final history = <bool>[];
  int hits = 0;
  int misses = 0;
  int profit = 0;
  int maxWinStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int currentLoseStreak = 0;

  const stakePerNumber = 1;
  const payoutPerHit = 70;

  for (int i = 0; i < sortedData.length - 1; i++) {
    final today = sortedData[i];
    final tomorrow = sortedData[i + 1];
    final de = today.de;
    final deStats = allStats[de] ?? {};

    if (deStats.isEmpty) continue;

    if (cutLossThreshold != null) {
      final prevSelected = selector(
        de,
        deStats,
        pairStats?[de] ?? {},
      );
      if (shouldStopDueToCutLoss(deStats, prevSelected, cutLossThreshold)) {
        continue;
      }
    }

    final selected = selector(de, deStats, pairStats?[de] ?? {});

    if (selected.isEmpty) continue;

    final tomorrowOthersSet = tomorrow.others.toSet();
    bool hasHit = false;
    int hitCount = 0;

    for (final num in selected) {
      if (tomorrowOthersSet.contains(num)) {
        hasHit = true;
        final count = tomorrow.others.where((n) => n == num).length;
        hitCount += count;
      }
    }

    final totalStake = selected.length * stakePerNumber;
    final totalPayout = hitCount * payoutPerHit;
    final dayProfit = totalPayout - totalStake;

    profit += dayProfit;

    if (hasHit) {
      hits++;
      currentWinStreak++;
      currentLoseStreak = 0;
      if (currentWinStreak > maxWinStreak) {
        maxWinStreak = currentWinStreak;
      }
      history.add(true);
    } else {
      misses++;
      currentLoseStreak++;
      currentWinStreak = 0;
      if (currentLoseStreak > maxLoseStreak) {
        maxLoseStreak = currentLoseStreak;
      }
      history.add(false);
    }
  }

  final totalDays = hits + misses;
  final winrate = totalDays > 0 ? (hits / totalDays * 100) : 0.0;
  final roi = totalDays > 0 ? (profit / totalDays) : 0.0;

  return BacktestResult(
    selectedNumbers: [],
    method: methodName,
    totalDays: totalDays,
    hits: hits,
    misses: misses,
    winrate: winrate,
    profit: profit,
    roi: roi,
    maxWinStreak: maxWinStreak,
    maxLoseStreak: maxLoseStreak,
  );
}

Future<void> main() async {
  final data = await loadDataModels('data.csv');

  final dataWithDate = data
      .map((d) => (
            model: d,
            dateTime: DateTime.parse(d.date),
          ))
      .toList();
  dataWithDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final sortedData = dataWithDate.map((e) => e.model).toList();

  print('📊 BACKTEST THUẬT TOÁN CHỌN CẶP 2 SỐ TỪ DE');
  print('=' * 80);
  print('Tổng số ngày: ${sortedData.length}');
  print('Số ngày backtest: ${sortedData.length - 1}\n');

  print('🔨 Đang xây dựng thống kê...');
  final allStats = buildNumberStats(sortedData);
  final pairStats = buildPairStats(sortedData, allStats);
  print('✅ Hoàn thành thống kê\n');

  final results = <BacktestResult>[];

  results.add(backtestMethod(
    'Top 2 theo Winrate',
    sortedData,
    allStats,
    (de, deStats, _) {
      final sorted = deStats.values.toList()
        ..sort((a, b) => b.winrate.compareTo(a.winrate));
      return sorted.take(2).map((s) => s.number).toList();
    },
    null,
  ));

  results.add(backtestMethod(
    'Top 2 theo Frequency',
    sortedData,
    allStats,
    (de, deStats, _) {
      final sorted = deStats.values.toList()
        ..sort((a, b) => b.frequency.compareTo(a.frequency));
      return sorted.take(2).map((s) => s.number).toList();
    },
    null,
  ));

  results.add(backtestMethod(
    'Voting (≥3 phương pháp)',
    sortedData,
    allStats,
    (de, deStats, dePairStats) {
      return votingMethod(deStats, dePairStats, 5);
    },
    pairStats,
  ));

  results.add(backtestMethod(
    'Top 2 + Max LOSE ≤10 filter',
    sortedData,
    allStats,
    (de, deStats, _) {
      final filtered = filterByMaxLoseStreak(deStats, 10);
      final filteredStats = filtered.map((n) => deStats[n]!).toList()
        ..sort((a, b) => b.winrate.compareTo(a.winrate));
      return filteredStats.take(2).map((s) => s.number).toList();
    },
    null,
  ));

  results.add(backtestMethod(
    'Conditional Prob sau L/LL',
    sortedData,
    allStats,
    (de, deStats, _) {
      final condProbs = calculateConditionalProbability(deStats);
      final sorted = condProbs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(2).map((e) => e.key).toList();
    },
    null,
  ));

  results.add(backtestMethod(
    'Top 2 + Cut-loss (streak≥8)',
    sortedData,
    allStats,
    (de, deStats, _) {
      final sorted = deStats.values.toList()
        ..sort((a, b) => b.winrate.compareTo(a.winrate));
      return sorted.take(2).map((s) => s.number).toList();
    },
    null,
    cutLossThreshold: 8,
  ));

  results.sort((a, b) {
    final winrateCompare = b.winrate.compareTo(a.winrate);
    if (winrateCompare != 0) return winrateCompare;
    return b.roi.compareTo(a.roi);
  });

  print('📈 KẾT QUẢ BACKTEST:');
  print('=' * 80);
  print('');

  for (int i = 0; i < results.length; i++) {
    final r = results[i];
    print('${i + 1}. ${r.method}');
    print('   ├─ Winrate: ${r.winrate.toStringAsFixed(2)}% (${r.hits}/${r.totalDays})');
    print('   ├─ ROI/lần: ${r.roi.toStringAsFixed(2)} điểm');
    print('   ├─ Tổng profit: ${r.profit} điểm');
    print('   ├─ Max WIN streak: ${r.maxWinStreak}');
    print('   └─ Max LOSE streak: ${r.maxLoseStreak}');
    print('');
  }

  final best = results.first;
  print('🏆 PHƯƠNG PHÁP TỐT NHẤT: ${best.method}');
  print('   Winrate: ${best.winrate.toStringAsFixed(2)}%');
  print('   ROI/lần: ${best.roi.toStringAsFixed(2)} điểm');

  final latestDe = sortedData.last.de;
  final latestDeStats = allStats[latestDe] ?? {};
  if (latestDeStats.isNotEmpty) {
    print('\n📋 TOP 2 SỐ CHO DE $latestDe (ngày gần nhất):');
    final topNumbers = latestDeStats.values.toList()
      ..sort((a, b) => b.winrate.compareTo(a.winrate));
    final top2 = topNumbers.take(2).toList();
    for (final stat in top2) {
      print('  ${stat.number}');
    }
  }
}
