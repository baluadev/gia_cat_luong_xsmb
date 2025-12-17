import 'dart:io';
import 'dart:math';

import 'data_model.dart';

class RoiStat {
  int hit = 0;
  int total = 0;
  int profit = 0;

  double get winrate => total == 0 ? 0 : hit / total * 100;
  double get roiPerTurn => total == 0 ? 0 : profit / total;
}

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

/// =======================
/// POWER SCORE
/// =======================
extension RoiPower on RoiStat {
  double powerScore(int cost) {
    if (total == 0) return 0;

    final winrateScore = (winrate - 35) * 1.5; // >35% mới có lợi
    final roiScore = roiPerTurn / cost;
    final stabilityScore = log(total);

    return winrateScore + roiScore + stabilityScore;
  }
}

/// =======================
/// CONFIG
/// =======================
const int POINT_PER_NUMBER = 5; // mặc định nếu đánh đều 3 số
const int COST_PER_POINT = 22500;
const int PROFIT_PER_HIT_PER_POINT = 57500; // ví dụ lợi nhuận 1 điểm trúng

/// =======================
/// MAIN
/// =======================
Future<void> main() async {
  // =======================
  // LOAD + SORT
  // =======================
  final data = await loadDataModels('data.csv');
  data.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

  // =======================
  // MAP: DE -> OTHER NGÀY MAI
  // =======================
  final Map<int, List<int>> nextDayStats = {};

  for (int i = 0; i < data.length - 1; i++) {
    final deToday = data[i].de;
    nextDayStats.putIfAbsent(deToday, () => []);
    nextDayStats[deToday]!.addAll(data[i + 1].others);
  }

  // =======================
  // TOP 3 BY DE
  // =======================
  final Map<int, List<int>> top3ByDe = {};
  nextDayStats.forEach((de, nums) {
    final Map<int, int> counter = {};
    for (final n in nums) {
      counter[n] = (counter[n] ?? 0) + 1;
    }

    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    top3ByDe[de] = sorted.take(2).map((e) => e.key).toList();
  });

  // =======================
  // ROI: HIT + TOTAL
  // =======================
  final Map<int, RoiStat> roiStats = {};
  for (int i = 0; i < data.length - 1; i++) {
    final deToday = data[i].de;
    final top3 = top3ByDe[deToday];
    if (top3 == null) continue;

    final hit = top3.any(data[i + 1].others.contains);

    roiStats.putIfAbsent(deToday, () => RoiStat());
    final s = roiStats[deToday]!;

    s.total++;
    if (hit) s.hit++;
  }

  // =======================
  // TÍNH PROFIT (CHUẨN)
  // =======================
  roiStats.forEach((_, s) {
    final miss = s.total - s.hit;
    s.profit = s.hit * PROFIT_PER_HIT_PER_POINT * POINT_PER_NUMBER -
        miss * POINT_PER_NUMBER * COST_PER_POINT;
  });

  // =======================
  // DỰ ĐOÁN + PHÂN BỐ ĐIỂM
  // =======================
  final latestDe = data.last.de;
  final predTop3 = top3ByDe[latestDe] ?? [];

  print('\n=====================START==============================');
  print('DE NGÀY GẦN NHẤT: $latestDe');
  print('→ TOP 3 DỰ ĐOÁN: $predTop3');

  if (roiStats.containsKey(latestDe)) {
    final s = roiStats[latestDe]!;
    print(
        'Hit ${s.hit}/${s.total} | Winrate ${s.winrate.toStringAsFixed(2)}% | Profit ${s.profit} | ROI/lần ${s.roiPerTurn.toStringAsFixed(0)}');

    final evCalc = EvCalculator(
      payout: PROFIT_PER_HIT_PER_POINT.toDouble(),
      stake: COST_PER_POINT.toDouble(),
    );
    final evDecisions = evCalc.decide(
      predTop3,
      nextDayStats[latestDe] != null
          ? {
              for (var n in nextDayStats[latestDe]!)
                n: nextDayStats[latestDe]!.where((x) => x == n).length
            }
          : {},
      s.total,
      minEv: 0.0,
    );

    if (evDecisions.isEmpty) {
      print('❌ Không con nào đủ EV → nghỉ hôm nay');
    } else {
      print('✅ Quyết định đánh ngày mai:');

      // Nhập tổng điểm hôm nay muốn đánh
      int totalPointsToday = 15; // ví dụ đánh 15 điểm hôm nay

      for (var d in evDecisions) {
        int pointsForNumber = max(1, (totalPointsToday * d.fraction).round());
        int cost = pointsForNumber * COST_PER_POINT;
        int profit = pointsForNumber * PROFIT_PER_HIT_PER_POINT;
        print(
            'Number ${d.number.toString().padLeft(2, '0')} → Points: $pointsForNumber | Cost: $cost | Profit: $profit | Fraction: ${(d.fraction * 100).toStringAsFixed(1)}% | EV: ${d.ev.toStringAsFixed(2)}');
      }
    }
  } else {
    print('Chưa có dữ liệu lịch sử cho DE này');
  }
  print('========================END===========================');
}

/// =======================
/// TÍNH EV & DECIDE
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
  final double payout; // lợi nhuận trên 1 điểm
  final double stake; // COST mỗi điểm

  EvCalculator({this.payout = 3.55, this.stake = 1.0});

  double computeEv(double probability) =>
      probability * payout - (1 - probability) * stake;

  List<EvDecision> decide(
      List<int> numbers, Map<int, int> counts, int totalDays,
      {double minEv = 0.0}) {
    final List<EvDecision> list = [];
    double totalEv = 0;

    for (var n in numbers) {
      final p = (counts[n] ?? 0) / totalDays;
      final ev = computeEv(p);
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
    return list;
  }
}
