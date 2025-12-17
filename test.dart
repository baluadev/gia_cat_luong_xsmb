import 'dart:io';

import 'data_model.dart';

/// =======================
/// LOAD CSV
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

/// =======================
/// CONFIG
/// =======================
const int POINT_PER_NUMBER = 5;
const int BASE_STAKE = 22500;
const int MAX_NUM_PER_DAY = 3; // max số đánh/ngày

const int COST_PER_NUMBER = POINT_PER_NUMBER * BASE_STAKE;
const int PROFIT_PER_HIT = POINT_PER_NUMBER * 80000 - COST_PER_NUMBER;

/// =======================
/// EV DECISION
/// =======================
class EvDecision {
  final int number;
  final double ev;
  double fraction;
  EvDecision(this.number, this.ev, this.fraction);

  @override
  String toString() =>
      'Number: ${number.toString().padLeft(2, '0')} | EV: ${ev.toStringAsFixed(3)} | Fraction: ${(fraction * 100).toStringAsFixed(1)}%';
}

class EvCalculator {
  // EV simplified = xác suất xuất hiện lịch sử
  List<EvDecision> decide(
      List<int> numbers, Map<int, int> counts, int totalDays,
      {double minEv = 0.0}) {
    final List<EvDecision> list = [];
    double totalEv = 0;

    for (var n in numbers) {
      final p = (counts[n] ?? 0) / totalDays;
      final ev = p; // EV ratio
      if (ev >= minEv) {
        list.add(EvDecision(n, ev, 0.0));
        totalEv += ev;
      }
    }

    if (list.isEmpty) return [];

    for (var d in list) {
      d.fraction = d.ev / totalEv;
    }

    list.sort((a, b) => b.ev.compareTo(a.ev));
    return list.take(MAX_NUM_PER_DAY).toList(); // chỉ đánh tối đa 3 số
  }
}

/// =======================
/// BACKTEST
/// =======================
class BacktestResult {
  int totalDays = 0;
  int daysPlayed = 0;
  int totalHits = 0;
  int totalNumbersPlayed = 0;
  int totalProfit = 0;

  double get winrate => totalDays == 0 ? 0 : totalHits / totalDays * 100;
  double get avgRoiPerDay =>
      totalDays == 0 ? 0 : totalProfit / totalDays.toDouble();
}

Future<void> runBacktest(List<DataModel> data) async {
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  // MAP: DE hôm nay -> các số OTHER ngày mai
  final Map<int, List<int>> nextDayStats = {};
  for (int i = 0; i < data.length - 1; i++) {
    final deToday = data[i].de;
    nextDayStats.putIfAbsent(deToday, () => []);
    nextDayStats[deToday]!.addAll(data[i + 1].others);
  }

  final evCalc = EvCalculator();
  final result = BacktestResult();

  for (int i = 0; i < data.length - 1; i++) {
    final today = data[i];
    final tomorrow = data[i + 1];

    result.totalDays++;

    final predTop3 = nextDayStats[today.de] ?? [];
    if (predTop3.isEmpty) continue;

    // counts lịch sử
    final counts = <int, int>{};
    for (var n in predTop3) {
      counts[n] = (counts[n] ?? 0) + 1;
    }

    final decisions =
        evCalc.decide(predTop3, counts, predTop3.length, minEv: 0.0);

    if (decisions.isEmpty) continue; // nghỉ hôm nay

    result.daysPlayed++;

    int hitsToday = 0;
    int costToday = 0;
    int profitToday = 0;

    for (var d in decisions) {
      // chia stake theo EV fraction
      int stakeToday = (COST_PER_NUMBER * d.fraction).round();
      costToday += stakeToday;
      if (tomorrow.others.contains(d.number)) {
        hitsToday++;
        profitToday += (PROFIT_PER_HIT * d.fraction).round();
      }
    }

    result.totalHits += (hitsToday > 0 ? 1 : 0); // tính winrate theo ngày
    result.totalNumbersPlayed += decisions.length;
    result.totalProfit += profitToday - costToday;
  }

  print('\n========= BACKTEST FULL (SOFT ALLOCATION) =========');
  print('Tổng số ngày       : ${result.totalDays}');
  print('Số ngày đánh       : ${result.daysPlayed}');
  print('Số ngày nghỉ       : ${result.totalDays - result.daysPlayed}');
  print(
      'Số số đánh trung bình/ngày : ${(result.totalNumbersPlayed / result.daysPlayed == 0 ? 1 : result.daysPlayed).toStringAsFixed(2)}');
  print('Tổng số ngày trúng  : ${result.totalHits}');
  print('Winrate trung bình  : ${result.winrate.toStringAsFixed(2)}%');
  print('ROI trung bình/ngày : ${result.avgRoiPerDay.toStringAsFixed(0)}');
  print('=================================');
}

Future<void> main() async {
  final data = await loadDataModels('data.csv');
  await runBacktest(data);
}
