import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'data_model.dart';

/// =======================
/// CONFIG
/// =======================
const String DATA_PATH = 'data.csv';
const String PLANS_DIR = 'plans';
const String RESULTS_DIR = 'results';
const String CONFIG_FILE = 'config.json';

// Giá trị mặc định
const int DEFAULT_POINTS_PER_NUMBER = 10;
const int COST_PER_POINT = 22500;
const int PAYOUT_PER_POINT = 80000;
const int XIEN_2_AMOUNT = 20000;
const int XIEN_3_AMOUNT = 10000;
const double STOP_LOSS_PERCENTAGE = 30.0;

/// =======================
/// DATA MODELS
/// =======================
class Plan {
  final String planId;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // active, completed, stopped
  final String strategy;
  final double totalCapital;
  final List<PlanPair> pairs;
  final PlanXiens xiens;

  Plan({
    required this.planId,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.strategy,
    required this.totalCapital,
    required this.pairs,
    required this.xiens,
  });

  Map<String, dynamic> toJson() => {
        'plan_id': planId,
        'created_at': createdAt.toIso8601String(),
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'status': status,
        'strategy': strategy,
        'total_capital': totalCapital,
        'pairs': pairs.map((p) => p.toJson()).toList(),
        'xiens': xiens.toJson(),
      };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        planId: json['plan_id'],
        createdAt: DateTime.parse(json['created_at']),
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        status: json['status'],
        strategy: json['strategy'],
        totalCapital: json['total_capital'].toDouble(),
        pairs: (json['pairs'] as List)
            .map((p) => PlanPair.fromJson(p))
            .toList(),
        xiens: PlanXiens.fromJson(json['xiens']),
      );
}

class PlanPair {
  final String pairId;
  final List<int> numbers;
  final int option; // 1, 2, or 3
  final double signalScore;
  final Map<String, double> capital; // day1, day2, day3
  final Map<String, dynamic> stopLoss;
  final String status;

  PlanPair({
    required this.pairId,
    required this.numbers,
    required this.option,
    required this.signalScore,
    required this.capital,
    required this.stopLoss,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'pair_id': pairId,
        'numbers': numbers,
        'option': option,
        'signal_score': signalScore,
        'capital': capital,
        'stop_loss': stopLoss,
        'status': status,
      };

  factory PlanPair.fromJson(Map<String, dynamic> json) => PlanPair(
        pairId: json['pair_id'],
        numbers: (json['numbers'] as List).map((e) => e as int).toList(),
        option: json['option'],
        signalScore: json['signal_score'].toDouble(),
        capital: Map<String, double>.from(
            (json['capital'] as Map).map((k, v) => MapEntry(k, v.toDouble()))),
        stopLoss: json['stop_loss'] as Map<String, dynamic>,
        status: json['status'],
      );
}

class PlanXiens {
  final Map<String, dynamic> xien2;
  final Map<String, dynamic> xien3;

  PlanXiens({required this.xien2, required this.xien3});

  Map<String, dynamic> toJson() => {
        'xien_2': xien2,
        'xien_3': xien3,
      };

  factory PlanXiens.fromJson(Map<String, dynamic> json) => PlanXiens(
        xien2: json['xien_2'] as Map<String, dynamic>,
        xien3: json['xien_3'] as Map<String, dynamic>,
      );
}

class DayResult {
  final String date;
  final String planId;
  final int dayNumber;
  final List<PairResult> results;
  final double totalProfitLoss;
  final double cumulativePnl;
  final String status; // win, loss, break_even

  DayResult({
    required this.date,
    required this.planId,
    required this.dayNumber,
    required this.results,
    required this.totalProfitLoss,
    required this.cumulativePnl,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'plan_id': planId,
        'day_number': dayNumber,
        'results': results.map((r) => r.toJson()).toList(),
        'total_profit_loss': totalProfitLoss,
        'cumulative_pnl': cumulativePnl,
        'status': status,
      };

  factory DayResult.fromJson(Map<String, dynamic> json) => DayResult(
        date: json['date'],
        planId: json['plan_id'],
        dayNumber: json['day_number'],
        results: (json['results'] as List)
            .map((r) => PairResult.fromJson(r))
            .toList(),
        totalProfitLoss: json['total_profit_loss'].toDouble(),
        cumulativePnl: json['cumulative_pnl'].toDouble(),
        status: json['status'],
      );
}

class PairResult {
  final String pairId;
  final List<int> numbersHit;
  final List<int> numbersMissed;
  final double capitalUsed;
  final double profitLoss;
  final Map<String, dynamic> xiens;

  PairResult({
    required this.pairId,
    required this.numbersHit,
    required this.numbersMissed,
    required this.capitalUsed,
    required this.profitLoss,
    required this.xiens,
  });

  Map<String, dynamic> toJson() => {
        'pair_id': pairId,
        'numbers_hit': numbersHit,
        'numbers_missed': numbersMissed,
        'capital_used': capitalUsed,
        'profit_loss': profitLoss,
        'xiens': xiens,
      };

  factory PairResult.fromJson(Map<String, dynamic> json) => PairResult(
        pairId: json['pair_id'],
        numbersHit: (json['numbers_hit'] as List).map((e) => e as int).toList(),
        numbersMissed:
            (json['numbers_missed'] as List).map((e) => e as int).toList(),
        capitalUsed: json['capital_used'].toDouble(),
        profitLoss: json['profit_loss'].toDouble(),
        xiens: json['xiens'] as Map<String, dynamic>,
      );
}

/// =======================
/// PAIR STATISTICS (Reuse from find_best_number.dart)
/// =======================
class PairStat {
  final int num1;
  final int num2;
  int hit = 0;
  int total = 0;
  int currentLoseStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int maxWinStreak = 0;
  final List<bool> history = [];
  int maxLoseReachedCount = 0;
  String? lastMaxLoseDate;
  final List<String> hitDates = [];
  final List<String> appearDates = [];

  PairStat(this.num1, this.num2);

  double get winrate => total == 0 ? 0 : (hit / total) * 100;

  double get compositeScore {
    if (maxLoseStreak == 0) return 0;
    final loseScore = 100.0 / maxLoseStreak; // MaxLose ngắn = tốt
    final winrateScore = winrate * 0.1;
    final stabilityScore = log(total + 1) * 2;
    return loseScore + winrateScore + stabilityScore;
  }

  double get signalScore {
    if (maxLoseStreak == 0) return 0;
    final loseRatio = currentLoseStreak / maxLoseStreak;
    final loseScore = loseRatio * 40; // 0-40 điểm
    final winrateScore = winrate * 0.5; // 0-50 điểm
    final maxLoseScore = (100 - maxLoseStreak) * 0.1; // 0-10 điểm
    return loseScore + winrateScore + maxLoseScore;
  }

  String get pairKey => '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}';
}

/// =======================
/// TRIPLE STATISTICS
/// =======================
class TripleStat {
  final int num1;
  final int num2;
  final int num3;
  int hit = 0;
  int total = 0;
  int currentLoseStreak = 0;
  int maxLoseStreak = 0;
  int currentWinStreak = 0;
  int maxWinStreak = 0;
  final List<bool> history = [];
  int maxLoseReachedCount = 0;
  String? lastMaxLoseDate;
  final List<String> hitDates = [];
  final List<String> appearDates = [];

  TripleStat(this.num1, this.num2, this.num3);

  double get winrate => total == 0 ? 0 : (hit / total) * 100;

  double get compositeScore {
    if (total == 0) return 0;
    final maxLoseScore = maxLoseStreak == 0
        ? 50.0
        : 50.0 - (maxLoseStreak / 100.0) * 50.0;
    final winrateScore = (winrate / 100.0) * 50.0;
    final stabilityScore = min(log(total + 1) * 2.0, 10.0);
    return maxLoseScore + winrateScore + stabilityScore;
  }

  double get signalScore {
    if (maxLoseStreak == 0) return 0;
    final loseRatio = currentLoseStreak / maxLoseStreak;
    final loseScore = loseRatio * 40;
    final winrateScore = winrate * 0.5;
    final maxLoseScore = (100 - maxLoseStreak) * 0.1;
    return loseScore + winrateScore + maxLoseScore;
  }

  String get tripleKey => '${num1.toString().padLeft(2, '0')}-${num2.toString().padLeft(2, '0')}-${num3.toString().padLeft(2, '0')}';
}

/// =======================
/// FILE UTILITIES
/// =======================
Future<void> ensureDirectories() async {
  final plansDir = Directory(PLANS_DIR);
  final resultsDir = Directory(RESULTS_DIR);
  if (!await plansDir.exists()) await plansDir.create();
  if (!await resultsDir.exists()) await resultsDir.create();
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

Future<void> savePlan(Plan plan) async {
  await ensureDirectories();
  final file = File('$PLANS_DIR/${plan.planId}.json');
  await file.writeAsString(jsonEncode(plan.toJson()));
}

Future<Plan?> loadPlan(String planId) async {
  try {
    final file = File('$PLANS_DIR/$planId.json');
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return Plan.fromJson(jsonDecode(content));
  } catch (e) {
    return null;
  }
}

Future<Plan?> loadActivePlan() async {
  await ensureDirectories();
  final dir = Directory(PLANS_DIR);
  final files = await dir.list().toList();
  
  for (final file in files) {
    if (file is File && file.path.endsWith('.json')) {
      final plan = await loadPlan(file.path.split('/').last.split('.').first);
      if (plan != null && plan.status == 'active') {
        return plan;
      }
    }
  }
  return null;
}

Future<void> saveResult(DayResult result) async {
  await ensureDirectories();
  final file = File('$RESULTS_DIR/result_${result.date}.json');
  await file.writeAsString(jsonEncode(result.toJson()));
}

Future<DayResult?> loadResult(String date) async {
  try {
    final file = File('$RESULTS_DIR/result_$date.json');
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return DayResult.fromJson(jsonDecode(content));
  } catch (e) {
    return null;
  }
}

/// =======================
/// ANALYSIS MODULE
/// =======================
Future<Map<String, PairStat>> analyzePairs(bool useOrLogic) async {
  final data = await loadDataModels(DATA_PATH);
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  final pairStats = <String, PairStat>{};

  // Tạo tất cả cặp số
  for (int i = 0; i < 100; i++) {
    for (int j = i + 1; j < 100; j++) {
      final pair = PairStat(i, j);
      pairStats[pair.pairKey] = pair;
    }
  }

  // Tính toán thống kê
  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];

    final todayOthers = today.others.toSet();
    final tomorrowOthers = tomorrow.others.toSet();

    for (final pair in pairStats.values) {
      final existsToday = useOrLogic
          ? todayOthers.contains(pair.num1) || todayOthers.contains(pair.num2)
          : todayOthers.contains(pair.num1) && todayOthers.contains(pair.num2);

      if (existsToday) {
        pair.total++;
        pair.appearDates.add(today.date);

        final existsTomorrow = useOrLogic
            ? tomorrowOthers.contains(pair.num1) ||
                tomorrowOthers.contains(pair.num2)
            : tomorrowOthers.contains(pair.num1) &&
                tomorrowOthers.contains(pair.num2);

        if (existsTomorrow) {
          pair.hit++;
          pair.hitDates.add(today.date);
          pair.history.add(true);
        } else {
          pair.history.add(false);
        }
      }
    }
  }

  // Tính lại streaks từ appearDates
  for (final pair in pairStats.values) {
    if (pair.appearDates.isEmpty) continue;

    final appearIndices = <int>[];
    for (int i = 0; i < data.length; i++) {
      if (pair.appearDates.contains(data[i].date)) {
        appearIndices.add(i);
      }
    }

    // Tính maxLoseStreak
    pair.maxLoseStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempLoseStreak = 0;
      int prevIndex = appearIndices[0];

      for (int i = 1; i < appearIndices.length; i++) {
        final gap = appearIndices[i] - prevIndex - 1;
        if (gap > 0) {
          tempLoseStreak += gap;
          pair.maxLoseStreak = max(pair.maxLoseStreak, tempLoseStreak);
          tempLoseStreak = 0;
        }
        prevIndex = appearIndices[i];
      }
    }

    // Tính currentLoseStreak
    if (appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      pair.currentLoseStreak = data.length - 1 - lastAppearIndex;
    }

    // Tính win streaks
    pair.currentWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      for (int i = data.length - 1; i >= 0; i--) {
        if (appearIndices.contains(i)) {
          pair.currentWinStreak++;
        } else {
          break;
        }
      }
    }

    pair.maxWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempWinStreak = 0;
      int prevIndex = -2;
      for (final appearIndex in appearIndices) {
        if (appearIndex == prevIndex + 1) {
          tempWinStreak++;
        } else {
          pair.maxWinStreak = max(pair.maxWinStreak, tempWinStreak);
          tempWinStreak = 1;
        }
        prevIndex = appearIndex;
      }
      pair.maxWinStreak = max(pair.maxWinStreak, tempWinStreak);
    }
  }

  return pairStats;
}

List<PairStat> getTopPairs(Map<String, PairStat> pairStats, bool isOption1) {
  final allPairs = pairStats.values.toList();
  final filtered = allPairs.where((p) => p.total >= 3).toList();

  final qualified = filtered.where((p) {
    if (isOption1) {
      if (p.winrate >= 8.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentLoseStreak > 0) {
          final ratio = p.currentLoseStreak / p.maxLoseStreak;
          if (ratio >= 0.8) return true;
        }
      }
      if (p.winrate >= 5.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 30) {
        if (p.currentWinStreak > 0) return true;
      }
      if (p.winrate >= 8.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentWinStreak == 1) return true;
      }
    } else {
      if (p.winrate >= 6.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 50) {
        if (p.currentLoseStreak > 0) {
          final ratio = p.currentLoseStreak / p.maxLoseStreak;
          if (ratio >= 0.75) return true;
        }
      }
      if (p.winrate >= 4.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 40) {
        if (p.currentWinStreak > 0) return true;
      }
      if (p.winrate >= 6.0 && p.maxLoseStreak > 0 && p.maxLoseStreak <= 50) {
        if (p.currentWinStreak == 1) return true;
      }
    }
    return false;
  }).toList();

  qualified.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  return qualified.take(20).toList();
}

/// =======================
/// ANALYZE TRIPLES
/// =======================
Future<Map<String, TripleStat>> analyzeTriples() async {
  final data = await loadDataModels(DATA_PATH);
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  final tripleStats = <String, TripleStat>{};

  // Tạo tất cả bộ 3 số
  for (int num1 = 0; num1 < 100; num1++) {
    for (int num2 = num1 + 1; num2 < 100; num2++) {
      for (int num3 = num2 + 1; num3 < 100; num3++) {
        final key = '${num1}_${num2}_$num3';
        tripleStats[key] = TripleStat(num1, num2, num3);
      }
    }
  }

  // Tính toán thống kê
  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];
    final todayNumbers = today.others.toSet();
    final tomorrowNumbers = tomorrow.others.toSet();

    for (final triple in tripleStats.values) {
      final existsToday = todayNumbers.contains(triple.num1) &&
          todayNumbers.contains(triple.num2) &&
          todayNumbers.contains(triple.num3);

      if (existsToday) {
        triple.total++;
        triple.appearDates.add(today.date);

        final existsTomorrow = tomorrowNumbers.contains(triple.num1) &&
            tomorrowNumbers.contains(triple.num2) &&
            tomorrowNumbers.contains(triple.num3);

        if (existsTomorrow) {
          triple.hit++;
          triple.hitDates.add(today.date);
          triple.history.add(true);
        } else {
          triple.history.add(false);
        }
      }
    }
  }

  // Tính lại streaks từ appearDates
  for (final triple in tripleStats.values) {
    if (triple.appearDates.isEmpty) continue;

    final appearIndices = <int>[];
    for (int i = 0; i < data.length; i++) {
      if (triple.appearDates.contains(data[i].date)) {
        appearIndices.add(i);
      }
    }

    // Tính maxLoseStreak
    triple.maxLoseStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempLoseStreak = 0;
      int prevIndex = appearIndices[0];
      for (int i = 1; i < appearIndices.length; i++) {
        final gap = appearIndices[i] - prevIndex - 1;
        if (gap > 0) {
          tempLoseStreak += gap;
          triple.maxLoseStreak = max(triple.maxLoseStreak, tempLoseStreak);
          tempLoseStreak = 0;
        }
        prevIndex = appearIndices[i];
      }
    }

    // Tính currentLoseStreak
    if (appearIndices.isNotEmpty) {
      final lastAppearIndex = appearIndices.last;
      triple.currentLoseStreak = data.length - 1 - lastAppearIndex;
    }

    // Tính win streaks
    triple.currentWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      for (int i = data.length - 1; i >= 0; i--) {
        if (appearIndices.contains(i)) {
          triple.currentWinStreak++;
        } else {
          break;
        }
      }
    }

    triple.maxWinStreak = 0;
    if (appearIndices.isNotEmpty) {
      int tempWinStreak = 0;
      int prevIndex = -2;
      for (final appearIndex in appearIndices) {
        if (appearIndex == prevIndex + 1) {
          tempWinStreak++;
        } else {
          triple.maxWinStreak = max(triple.maxWinStreak, tempWinStreak);
          tempWinStreak = 1;
        }
        prevIndex = appearIndex;
      }
      triple.maxWinStreak = max(triple.maxWinStreak, tempWinStreak);
    }
  }

  return tripleStats;
}

List<TripleStat> getTopTriples(Map<String, TripleStat> tripleStats) {
  final allTriples = tripleStats.values.toList();
  final filtered = allTriples.where((t) => t.total >= 2).toList();

  final qualified = filtered.where((t) {
    // Khuyến nghị 1: Winrate >= 3% + MaxLose <= 80 + Lose streak >= 70% của MaxLose
    if (t.winrate >= 3.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 80) {
      if (t.currentLoseStreak > 0) {
        final ratio = t.currentLoseStreak / t.maxLoseStreak;
        if (ratio >= 0.7) return true;
      }
    }
    // Khuyến nghị 2: Winrate >= 2% + MaxLose <= 60 + Đang win streak
    if (t.winrate >= 2.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 60) {
      if (t.currentWinStreak > 0) return true;
    }
    // Khuyến nghị 3: Winrate >= 3% + MaxLose <= 80 + Vừa mới xuất hiện (currentWinStreak = 1)
    if (t.winrate >= 3.0 && t.maxLoseStreak > 0 && t.maxLoseStreak <= 80) {
      if (t.currentWinStreak == 1) return true;
    }
    return false;
  }).toList();

  qualified.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  return qualified.take(20).toList();
}

/// =======================
/// PLANNING MODULE
/// =======================
Future<Plan> createPlan(List<PairStat> selectedPairs, String strategy) async {
  final now = DateTime.now();
  final planId = '${now.toIso8601String().split('T')[0]}_${now.millisecondsSinceEpoch % 1000}';

  final pairs = selectedPairs.map((pairStat) {
    final capitalPerDay = DEFAULT_POINTS_PER_NUMBER * 2 * COST_PER_POINT; // 2 số mỗi cặp
    return PlanPair(
      pairId: pairStat.pairKey,
      numbers: [pairStat.num1, pairStat.num2],
      option: 1,
      signalScore: pairStat.signalScore,
      capital: {
        'day1': capitalPerDay.toDouble(),
        'day2': capitalPerDay.toDouble(),
        'day3': capitalPerDay.toDouble(),
      },
      stopLoss: {
        'type': 'percentage',
        'value': STOP_LOSS_PERCENTAGE,
      },
      status: 'active',
    );
  }).toList();

  final totalCapital = pairs.fold<double>(
      0.0, (sum, p) => sum + p.capital['day1']! + XIEN_2_AMOUNT * 2 + XIEN_3_AMOUNT * 4);

  final xiens = PlanXiens(
    xien2: {
      'pairs': pairs.map((p) => p.pairId).toList(),
      'amount_per_day': XIEN_2_AMOUNT,
    },
    xien3: {
      'combinations': 4,
      'amount_per_combination': XIEN_3_AMOUNT,
    },
  );

  final plan = Plan(
    planId: planId,
    createdAt: now,
    startDate: now,
    endDate: now.add(Duration(days: 2)),
    status: 'active',
    strategy: strategy,
    totalCapital: totalCapital,
    pairs: pairs,
    xiens: xiens,
  );

  await savePlan(plan);
  return plan;
}

/// =======================
/// DECISION MODULE
/// =======================
class Decision {
  final String action; // CONTINUE, STOP, ADJUST
  final String reason;
  final Plan? adjustedPlan;

  Decision({
    required this.action,
    required this.reason,
    this.adjustedPlan,
  });
}

Future<Decision> makeDecision(Plan plan, List<DayResult> previousResults) async {
  if (previousResults.isEmpty) {
    return Decision(action: 'CONTINUE', reason: 'Ngày đầu tiên');
  }

  final totalCapital = plan.totalCapital;
  final cumulativeLoss = previousResults
      .where((r) => r.totalProfitLoss < 0)
      .fold<double>(0.0, (sum, r) => sum + r.totalProfitLoss.abs());

  // Kiểm tra dừng lỗ
  if (cumulativeLoss >= totalCapital * STOP_LOSS_PERCENTAGE / 100) {
    return Decision(
      action: 'STOP',
      reason: 'Đạt ngưỡng dừng lỗ: ${(cumulativeLoss / totalCapital * 100).toStringAsFixed(1)}%',
    );
  }

  // Kiểm tra 3 ngày liên tiếp thua
  if (previousResults.length >= 3) {
    final last3 = previousResults.sublist(previousResults.length - 3);
    final allLoss = last3.every((r) => r.status == 'loss');
    if (allLoss) {
      return Decision(
        action: 'STOP',
        reason: 'Thua liên tiếp 3 ngày',
      );
    }
  }

  // Điều chỉnh vốn dựa trên kết quả
  final lastResult = previousResults.last;
  if (lastResult.status == 'loss') {
    // Giảm vốn 50% cho các cặp thua
    final adjustedPairs = plan.pairs.map((pair) {
      final pairResult = lastResult.results.firstWhere(
        (r) => r.pairId == pair.pairId,
        orElse: () => PairResult(
          pairId: pair.pairId,
          numbersHit: [],
          numbersMissed: [],
          capitalUsed: 0,
          profitLoss: 0,
          xiens: {},
        ),
      );

      if (pairResult.numbersHit.length < pair.numbers.length / 2) {
        // Thua, giảm vốn
        return PlanPair(
          pairId: pair.pairId,
          numbers: pair.numbers,
          option: pair.option,
          signalScore: pair.signalScore,
          capital: {
            'day1': pair.capital['day1']! * 0.5,
            'day2': pair.capital['day2']! * 0.5,
            'day3': pair.capital['day3']! * 0.5,
          },
          stopLoss: pair.stopLoss,
          status: pair.status,
        );
      }
      return pair;
    }).toList();

    final adjustedPlan = Plan(
      planId: plan.planId,
      createdAt: plan.createdAt,
      startDate: plan.startDate,
      endDate: plan.endDate,
      status: plan.status,
      strategy: plan.strategy,
      totalCapital: adjustedPairs.fold<double>(
          0.0, (sum, p) => sum + p.capital['day1']! + XIEN_2_AMOUNT * 2 + XIEN_3_AMOUNT * 4),
      pairs: adjustedPairs,
      xiens: plan.xiens,
    );

    return Decision(
      action: 'ADJUST',
      reason: 'Điều chỉnh vốn sau khi thua',
      adjustedPlan: adjustedPlan,
    );
  }

  return Decision(action: 'CONTINUE', reason: 'Tiếp tục theo kế hoạch');
}

/// =======================
/// REPORTING MODULE
/// =======================
void printMenu() {
  print('\n╔════════════════════════════════════════╗');
  print('║     HỆ THỐNG QUẢN LÝ CHƠI             ║');
  print('╠════════════════════════════════════════╣');
  print('║ 1. Tạo kế hoạch mới                    ║');
  print('║ 2. Bắt đầu ngày chơi (Start)           ║');
  print('║ 3. Xem kế hoạch hiện tại               ║');
  print('║ 4. Xem lịch sử kết quả                 ║');
  print('║ 5. Thống kê tổng quan                  ║');
  print('║ 6. Thoát                               ║');
  print('╚════════════════════════════════════════╝');
}

void printPlan(Plan plan) {
  print('\n╔════════════════════════════════════════╗');
  print('║     KẾ HOẠCH: ${plan.planId.padRight(25)}║');
  print('╠════════════════════════════════════════╣');
  print('   Ngày bắt đầu: ${plan.startDate.toIso8601String().split('T')[0]}');
  print('   Ngày kết thúc: ${plan.endDate.toIso8601String().split('T')[0]}');
  print('   Trạng thái: ${plan.status}');
  print('   Chiến lược: ${plan.strategy}');
  print('   Tổng vốn: ${plan.totalCapital.toStringAsFixed(0)} VNĐ');
  print('\n   Các cặp số:');
  for (final pair in plan.pairs) {
    print('     - ${pair.pairId}: ${pair.numbers.map((n) => n.toString().padLeft(2, '0')).join(', ')}');
    print('       Vốn/ngày: ${pair.capital['day1']!.toStringAsFixed(0)} VNĐ');
  }
  print('╚════════════════════════════════════════╝');
}

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  await ensureDirectories();

  while (true) {
    printMenu();
    stdout.write('\nChọn chức năng (1-6): ');
    final choice = stdin.readLineSync()?.trim() ?? '';

    switch (choice) {
      case '1':
        await createNewPlan();
        break;
      case '2':
        await startDay();
        break;
      case '3':
        await viewCurrentPlan();
        break;
      case '4':
        await viewHistory();
        break;
      case '5':
        await viewStatistics();
        break;
      case '6':
        print('\nĐã thoát chương trình.');
        return;
      default:
        print('\n⚠️  Lựa chọn không hợp lệ!');
    }
  }
}

Future<void> createNewPlan() async {
  print('\n╔════════════════════════════════════════╗');
  print('║     TẠO KẾ HOẠCH MỚI                   ║');
  print('╚════════════════════════════════════════╝');

  print('\nChọn loại thống kê:');
  print('  1 = Option 1: Top cặp 2 số (1 trong 2 số xuất hiện)');
  print('  2 = Option 2: Top cặp 2 số (Cả 2 số phải xuất hiện cùng 1 ngày)');
  print('  3 = Option 3: Top bộ 3 số (Cả 3 số phải xuất hiện cùng 1 ngày)');
  stdout.write('\nNhập lựa chọn (1, 2 hoặc 3): ');
  final optionInput = stdin.readLineSync()?.trim() ?? '1';

  if (optionInput == '3') {
    await createPlanForTriplesMenu();
    return;
  }

  final isOption1 = optionInput == '1';
  final useOrLogic = isOption1;

  print('\nĐang phân tích dữ liệu...');
  final pairStats = await analyzePairs(useOrLogic);
  final topPairs = getTopPairs(pairStats, isOption1);

  if (topPairs.isEmpty) {
    print('\n⚠️  Không có cặp số nào đạt điều kiện khuyến nghị!');
    return;
  }

  print('\n═══════════════════════════════════════');
  print('TOP ${topPairs.length} CẶP SỐ TỐT NHẤT:');
  print('═══════════════════════════════════════');
  for (int i = 0; i < topPairs.length; i++) {
    final p = topPairs[i];
    final loseInfo = p.maxLoseStreak > 0 
        ? 'Lose: ${p.currentLoseStreak}/${p.maxLoseStreak}'
        : 'Chưa có dữ liệu';
    print('${(i + 1).toString().padLeft(2)}. ${p.pairKey} | Winrate: ${p.winrate.toStringAsFixed(2)}% | MaxLose: ${p.maxLoseStreak} | $loseInfo');
  }

  print('\nNhập các cặp số muốn chơi (ví dụ: 09-79,23-53 hoặc Enter để chọn top 2): ');
  final input = stdin.readLineSync()?.trim() ?? '';

  List<PairStat> selectedPairs;
  if (input.isEmpty) {
    selectedPairs = topPairs.take(2).toList();
    print('Đã chọn 2 cặp đầu tiên: ${selectedPairs.map((p) => p.pairKey).join(', ')}');
  } else {
    final pairKeys = input.split(',').map((s) => s.trim()).toList();
    selectedPairs = pairKeys
        .map((key) => pairStats[key])
        .where((p) => p != null)
        .cast<PairStat>()
        .toList();

    if (selectedPairs.isEmpty) {
      print('⚠️  Không tìm thấy cặp số nào!');
      return;
    }
  }

  stdout.write('\nChọn chiến lược (balanced/aggressive/conservative): ');
  final strategy = stdin.readLineSync()?.trim() ?? 'balanced';

  final plan = await createPlan(selectedPairs, strategy);
  print('\n✅ Đã tạo kế hoạch: ${plan.planId}');
  printPlan(plan);
}

Future<void> createPlanForTriplesMenu() async {
  print('\nĐang phân tích dữ liệu...');
  final tripleStats = await analyzeTriples();
  final topTriples = getTopTriples(tripleStats);

  if (topTriples.isEmpty) {
    print('\n⚠️  Không có bộ 3 số nào đạt điều kiện khuyến nghị!');
    return;
  }

  print('\n═══════════════════════════════════════');
  print('TOP ${topTriples.length} BỘ 3 SỐ TỐT NHẤT:');
  print('═══════════════════════════════════════');
  for (int i = 0; i < topTriples.length; i++) {
    final t = topTriples[i];
    final loseInfo = t.maxLoseStreak > 0
        ? 'Lose: ${t.currentLoseStreak}/${t.maxLoseStreak}'
        : 'Chưa có dữ liệu';
    print('${(i + 1).toString().padLeft(2)}. ${t.tripleKey} | Winrate: ${t.winrate.toStringAsFixed(2)}% | MaxLose: ${t.maxLoseStreak} | $loseInfo');
  }

  print('\nNhập các bộ 3 số muốn chơi (ví dụ: 09-79-23,16-49-53 hoặc Enter để chọn top 2): ');
  final input = stdin.readLineSync()?.trim() ?? '';

  List<TripleStat> selectedTriples;
  if (input.isEmpty) {
    selectedTriples = topTriples.take(2).toList();
    print('Đã chọn 2 bộ đầu tiên: ${selectedTriples.map((t) => t.tripleKey).join(', ')}');
  } else {
    final tripleKeys = input.split(',').map((s) => s.trim()).toList();
    selectedTriples = tripleKeys
        .map((key) {
          // Parse key từ format "09-79-23" thành "9_79_23"
          final parts = key.split('-');
          if (parts.length == 3) {
            final nums = parts.map((p) => int.parse(p.trim())).toList()..sort();
            final searchKey = '${nums[0]}_${nums[1]}_${nums[2]}';
            return tripleStats[searchKey];
          }
          return null;
        })
        .where((t) => t != null)
        .cast<TripleStat>()
        .toList();

    if (selectedTriples.isEmpty) {
      print('⚠️  Không tìm thấy bộ 3 số nào!');
      return;
    }
  }

  stdout.write('\nChọn chiến lược (balanced/aggressive/conservative): ');
  final strategy = stdin.readLineSync()?.trim() ?? 'balanced';

  final plan = await createPlanForTriples(selectedTriples, strategy);
  print('\n✅ Đã tạo kế hoạch: ${plan.planId}');
  printPlan(plan);
}

Future<Plan> createPlanForTriples(List<TripleStat> selectedTriples, String strategy) async {
  final now = DateTime.now();
  final planId = '${now.toIso8601String().split('T')[0]}_${now.millisecondsSinceEpoch % 1000}';

  // Convert TripleStat thành PlanPair với option = 3
  final pairs = selectedTriples.map((tripleStat) {
    final capitalPerDay = DEFAULT_POINTS_PER_NUMBER * 3 * COST_PER_POINT; // 3 số mỗi bộ
    return PlanPair(
      pairId: tripleStat.tripleKey,
      numbers: [tripleStat.num1, tripleStat.num2, tripleStat.num3],
      option: 3,
      signalScore: tripleStat.signalScore,
      capital: {
        'day1': capitalPerDay.toDouble(),
        'day2': capitalPerDay.toDouble(),
        'day3': capitalPerDay.toDouble(),
      },
      stopLoss: {
        'type': 'percentage',
        'value': STOP_LOSS_PERCENTAGE,
      },
      status: 'active',
    );
  }).toList();

  final totalCapital = pairs.fold<double>(
      0.0, (sum, p) => sum + p.capital['day1']! + XIEN_2_AMOUNT * 2 + XIEN_3_AMOUNT * 4);

  final xiens = PlanXiens(
    xien2: {
      'pairs': pairs.map((p) => p.pairId).toList(),
      'amount_per_day': XIEN_2_AMOUNT,
    },
    xien3: {
      'combinations': 4,
      'amount_per_combination': XIEN_3_AMOUNT,
    },
  );

  final plan = Plan(
    planId: planId,
    createdAt: now,
    startDate: now,
    endDate: now.add(Duration(days: 2)),
    status: 'active',
    strategy: strategy,
    totalCapital: totalCapital,
    pairs: pairs,
    xiens: xiens,
  );

  await savePlan(plan);
  return plan;
}

Future<void> startDay() async {
  print('\n╔════════════════════════════════════════╗');
  print('║     BẮT ĐẦU NGÀY CHƠI                  ║');
  print('╚════════════════════════════════════════╝');

  final plan = await loadActivePlan();
  if (plan == null) {
    print('\n⚠️  Không có kế hoạch đang hoạt động!');
    print('   Vui lòng tạo kế hoạch mới trước.');
    return;
  }

  final today = DateTime.now();
  final dayNumber = today.difference(plan.startDate).inDays + 1;

  if (dayNumber > 3) {
    print('\n⚠️  Kế hoạch đã kết thúc!');
    return;
  }

  print('\n📅 Ngày $dayNumber - ${today.toIso8601String().split('T')[0]}');

  // Load kết quả ngày trước
  if (dayNumber > 1) {
    final yesterday = today.subtract(Duration(days: 1));
    final yesterdayStr = yesterday.toIso8601String().split('T')[0];
    final yesterdayResult = await loadResult(yesterdayStr);

    if (yesterdayResult != null) {
      print('\n📊 KẾT QUẢ NGÀY ${dayNumber - 1}:');
      for (final result in yesterdayResult.results) {
        final hitCount = result.numbersHit.length;
        final totalCount = result.numbersHit.length + result.numbersMissed.length;
        final status = hitCount >= totalCount / 2 ? '✅' : '❌';
        print('   $status Cặp ${result.pairId}: $hitCount/$totalCount số về');
        print('      Lời/Lỗ: ${result.profitLoss >= 0 ? '+' : ''}${result.profitLoss.toStringAsFixed(0)} VNĐ');
      }
      print('   Tổng: ${yesterdayResult.totalProfitLoss >= 0 ? '+' : ''}${yesterdayResult.totalProfitLoss.toStringAsFixed(0)} VNĐ');

      // Đưa ra quyết định
      final allResults = <DayResult>[];
      for (int i = 1; i < dayNumber; i++) {
        final date = plan.startDate.add(Duration(days: i - 1));
        final dateStr = date.toIso8601String().split('T')[0];
        final result = await loadResult(dateStr);
        if (result != null) allResults.add(result);
      }

      final decision = await makeDecision(plan, allResults);
      print('\n💡 QUYẾT ĐỊNH: ${decision.action}');
      print('   Lý do: ${decision.reason}');

      if (decision.action == 'STOP') {
        final stoppedPlan = Plan(
          planId: plan.planId,
          createdAt: plan.createdAt,
          startDate: plan.startDate,
          endDate: plan.endDate,
          status: 'stopped',
          strategy: plan.strategy,
          totalCapital: plan.totalCapital,
          pairs: plan.pairs,
          xiens: plan.xiens,
        );
        await savePlan(stoppedPlan);
        print('\n⚠️  Kế hoạch đã được dừng!');
        return;
      }

      if (decision.action == 'ADJUST' && decision.adjustedPlan != null) {
        await savePlan(decision.adjustedPlan!);
        print('\n📝 Đã điều chỉnh kế hoạch!');
      }
    }
  }

  // Hiển thị kế hoạch ngày hôm nay
  print('\n🎯 KẾ HOẠCH NGÀY $dayNumber:');
  final currentPlan = await loadActivePlan();
  if (currentPlan != null) {
    double totalToday = 0;
    for (final pair in currentPlan.pairs) {
      final capital = pair.capital['day$dayNumber'] ?? pair.capital['day1']!;
      totalToday += capital;
      print('   Cặp ${pair.pairId}: ${pair.numbers.map((n) => n.toString().padLeft(2, '0')).join(', ')}');
      print('      Vốn: ${capital.toStringAsFixed(0)} VNĐ');
    }
    print('   Xiên 2: ${XIEN_2_AMOUNT * 2} VNĐ');
    print('   Xiên 3: ${XIEN_3_AMOUNT * 4} VNĐ');
    print('   Tổng: ${(totalToday + XIEN_2_AMOUNT * 2 + XIEN_3_AMOUNT * 4).toStringAsFixed(0)} VNĐ');
  }

  // Nhập kết quả
  print('\n📝 Nhập kết quả (Enter để bỏ qua, nhập sau):');
  stdout.write('   Các số đã về (ví dụ: 09,79,23): ');
  final hitInput = stdin.readLineSync()?.trim() ?? '';

  if (hitInput.isNotEmpty) {
    final hitNumbers = hitInput.split(',').map((s) => int.parse(s.trim())).toList();
    final results = <PairResult>[];

    for (final pair in currentPlan!.pairs) {
      final numbersHit = hitNumbers.where((n) => pair.numbers.contains(n)).toList();
      final numbersMissed = pair.numbers.where((n) => !hitNumbers.contains(n)).toList();
      final capital = pair.capital['day$dayNumber'] ?? pair.capital['day1']!;
      final points = capital / COST_PER_POINT / pair.numbers.length;

      double profitLoss = 0;
      profitLoss += numbersHit.length * points * PAYOUT_PER_POINT;
      profitLoss -= capital; // Trừ vốn đã đầu tư
      profitLoss -= XIEN_2_AMOUNT * 2; // Trừ xiên 2
      profitLoss -= XIEN_3_AMOUNT * 4; // Trừ xiên 3

      results.add(PairResult(
        pairId: pair.pairId,
        numbersHit: numbersHit,
        numbersMissed: numbersMissed,
        capitalUsed: capital,
        profitLoss: profitLoss,
        xiens: {
          'xien_2': {'hit': false, 'amount': -XIEN_2_AMOUNT * 2},
          'xien_3': {'hit': false, 'amount': -XIEN_3_AMOUNT * 4},
        },
      ));
    }

    final totalProfitLoss = results.fold<double>(0.0, (sum, r) => sum + r.profitLoss);
    final status = totalProfitLoss > 0
        ? 'win'
        : totalProfitLoss < 0
            ? 'loss'
            : 'break_even';

    final allResults = <DayResult>[];
    for (int i = 1; i < dayNumber; i++) {
      final date = currentPlan.startDate.add(Duration(days: i - 1));
      final dateStr = date.toIso8601String().split('T')[0];
      final result = await loadResult(dateStr);
      if (result != null) allResults.add(result);
    }

    final cumulativePnl = allResults.fold<double>(0.0, (sum, r) => sum + r.totalProfitLoss) +
        totalProfitLoss;

    final dayResult = DayResult(
      date: today.toIso8601String().split('T')[0],
      planId: currentPlan.planId,
      dayNumber: dayNumber,
      results: results,
      totalProfitLoss: totalProfitLoss,
      cumulativePnl: cumulativePnl,
      status: status,
    );

    await saveResult(dayResult);
    print('\n✅ Đã lưu kết quả ngày $dayNumber!');
  }
}

Future<void> viewCurrentPlan() async {
  final plan = await loadActivePlan();
  if (plan == null) {
    print('\n⚠️  Không có kế hoạch đang hoạt động!');
    return;
  }
  printPlan(plan);
}

Future<void> viewHistory() async {
  print('\n╔════════════════════════════════════════╗');
  print('║     LỊCH SỬ KẾT QUẢ                   ║');
  print('╚════════════════════════════════════════╝');

  final dir = Directory(RESULTS_DIR);
  if (!await dir.exists()) {
    print('\n⚠️  Chưa có kết quả nào!');
    return;
  }

  final files = await dir.list().toList();
  final results = <DayResult>[];

  for (final file in files) {
    if (file is File && file.path.endsWith('.json')) {
      final dateStr = file.path.split('_').last.split('.').first;
      final result = await loadResult(dateStr);
      if (result != null) results.add(result);
    }
  }

  results.sort((a, b) => a.date.compareTo(b.date));

  if (results.isEmpty) {
    print('\n⚠️  Chưa có kết quả nào!');
    return;
  }

  print('\n📊 Tổng cộng ${results.length} ngày:');
  for (final result in results) {
    print('\n   Ngày ${result.date} (Ngày ${result.dayNumber}):');
    print('      Tổng: ${result.totalProfitLoss >= 0 ? '+' : ''}${result.totalProfitLoss.toStringAsFixed(0)} VNĐ');
    print('      Trạng thái: ${result.status}');
  }

  final totalPnl = results.fold<double>(0.0, (sum, r) => sum + r.totalProfitLoss);
  print('\n   Tổng lời/lỗ: ${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(0)} VNĐ');
}

Future<void> viewStatistics() async {
  print('\n╔════════════════════════════════════════╗');
  print('║     THỐNG KÊ TỔNG QUAN                 ║');
  print('╚════════════════════════════════════════╝');

  final plan = await loadActivePlan();
  if (plan == null) {
    print('\n⚠️  Không có kế hoạch đang hoạt động!');
    return;
  }

  final dir = Directory(RESULTS_DIR);
  if (!await dir.exists()) {
    print('\n⚠️  Chưa có kết quả nào!');
    return;
  }

  final files = await dir.list().toList();
  final results = <DayResult>[];

  for (final file in files) {
    if (file is File && file.path.endsWith('.json')) {
      final dateStr = file.path.split('_').last.split('.').first;
      final result = await loadResult(dateStr);
      if (result != null && result.planId == plan.planId) {
        results.add(result);
      }
    }
  }

  if (results.isEmpty) {
    print('\n⚠️  Chưa có kết quả cho kế hoạch này!');
    return;
  }

  final totalPnl = results.fold<double>(0.0, (sum, r) => sum + r.totalProfitLoss);
  final winDays = results.where((r) => r.status == 'win').length;
  final lossDays = results.where((r) => r.status == 'loss').length;
  final winRate = results.isEmpty ? 0 : (winDays / results.length * 100);

  print('\n📊 Thống kê kế hoạch: ${plan.planId}');
  print('   Tổng số ngày: ${results.length}');
  print('   Số ngày thắng: $winDays');
  print('   Số ngày thua: $lossDays');
  print('   Tỷ lệ thắng: ${winRate.toStringAsFixed(1)}%');
  print('   Tổng lời/lỗ: ${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(0)} VNĐ');
  print('   ROI: ${(totalPnl / plan.totalCapital * 100).toStringAsFixed(2)}%');
}

